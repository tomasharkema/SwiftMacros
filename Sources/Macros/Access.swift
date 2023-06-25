import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct Access: AccessorMacro {
    public static func expansion<Context: MacroExpansionContext,
                                 Declaration: DeclSyntaxProtocol>(of node: AttributeSyntax,
                                                                  providingAccessorsOf declaration: Declaration,
                                                                  in context: Context) throws -> [AccessorDeclSyntax] {
        guard let firstArg = node.argument?.as(TupleExprElementListSyntax.self)?.first,
              let type = firstArg.type else {
            throw MacroDiagnostics.errorMacroUsage(message: "Must specify a content type")
        }
        if type == "userDefaults",
           let dataType = node.attributeName.as(SimpleTypeIdentifierSyntax.self)?.type {
            return processUserDefaults(for: declaration,
                                       userDefaults: firstArg.userDefaults,
                                       type: "\(dataType)")
        } else if type == "nsCache",
                  let cache = firstArg.cache,
                  let dataType = node.attributeName.as(SimpleTypeIdentifierSyntax.self)?.type {
            let isOptionalType = node.attributeName.as(SimpleTypeIdentifierSyntax.self)?.genericArgumentClause?.arguments
                .first?.as(GenericArgumentSyntax.self)?.argumentType.is(OptionalTypeSyntax.self) ?? false
            return processNSCache(for: declaration,
                                  cache: cache,
                                  type: "\(dataType)",
                                  isOptionalType: isOptionalType)
        }

        return []
    }

    private static func processUserDefaults(for declaration: DeclSyntaxProtocol,
                                            userDefaults: ExprSyntax,
                                            type: String) -> [AccessorDeclSyntax] {
        guard let binding = declaration.as(VariableDeclSyntax.self)?.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              binding.accessor == nil else { return [] }
        var defaultValue = ""
        if let value = binding.initializer?.value {
            defaultValue = " ?? \(value)"
        }
        let getAccessor: AccessorDeclSyntax =
          """
          get {
            (\(userDefaults).object(forKey: "AccessKey_\(raw: identifier)") as? \(raw: type))\(raw: defaultValue)
          }
          """

        let setAccessor: AccessorDeclSyntax =
          """
          set {
            \(userDefaults).set(newValue, forKey: "AccessKey_\(raw: identifier)")
          }
          """
        return [getAccessor, setAccessor]
    }

    private static func processNSCache(for declaration: DeclSyntaxProtocol,
                                       cache: ExprSyntax,
                                       type: String,
                                       isOptionalType: Bool) -> [AccessorDeclSyntax] {
        guard let binding = declaration.as(VariableDeclSyntax.self)?.bindings.first,
              let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
              binding.accessor == nil else { return [] }
        var defaultValue = ""
        if let value = binding.initializer?.value {
            defaultValue = " ?? \(value)"
        }
        let getAccessor: AccessorDeclSyntax =
          """
          get {
            (\(cache).object(forKey: "AccessKey_\(raw: identifier)" as NSString) as? \(raw: type))\(raw: defaultValue)
          }
          """
        let setAccessor: AccessorDeclSyntax
        if isOptionalType {
            setAccessor =
          """
          set {
            if let value = newValue {
              \(cache).setObject(value, forKey: "AccessKey_\(raw: identifier) as NSString")
            } else {
              \(cache).removeObject(forKey: "AccessKey_\(raw: identifier) as NSString")
            }
          }
          """
        } else {
            setAccessor =
          """
          set {
            \(cache).setObject(newValue, forKey: "AccessKey_\(raw: identifier) as NSString")
          }
          """
        }
        return [getAccessor, setAccessor]
    }
}

private extension TupleExprElementSyntax {
    var type: String? {
        expression.as(MemberAccessExprSyntax.self)?.name.text
        ?? expression.as(FunctionCallExprSyntax.self)?.calledExpression.as(MemberAccessExprSyntax.self)?.name.text
    }
}

private extension TupleExprElementSyntax {
    var userDefaults: ExprSyntax {
        if expression.is(MemberAccessExprSyntax.self) {
            return "UserDefaults.standard"
        }
        if let memeberAceess = expression.as(FunctionCallExprSyntax.self)?.argumentList.first?
            .as(TupleExprElementSyntax.self)?.expression.as(MemberAccessExprSyntax.self) {
            return "UserDefaults.\(raw: memeberAceess.name.text)"
        } else {
            return expression.as(FunctionCallExprSyntax.self)?.argumentList.first?.expression ?? "UserDefaults.standard"
        }
    }

    var cache: ExprSyntax? {
        expression.as(FunctionCallExprSyntax.self)?.argumentList.first?.as(TupleExprElementSyntax.self)?.expression
    }
}

private extension SimpleTypeIdentifierSyntax {
    var type: SyntaxProtocol? {
        genericArgumentClause?.arguments.first?.as(GenericArgumentSyntax.self)?.argumentType.as(OptionalTypeSyntax.self)?.wrappedType
        ?? genericArgumentClause?.arguments.first?.as(GenericArgumentSyntax.self)
    }
}
