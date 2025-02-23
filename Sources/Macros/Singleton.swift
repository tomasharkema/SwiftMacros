import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct Singleton: MemberMacro {
    public static func expansion<Declaration: DeclGroupSyntax,
                                 Context: MacroExpansionContext>(of node: AttributeSyntax,
                                                                 providingMembersOf declaration: Declaration,
                                                                 in context: Context) throws -> [DeclSyntax] {
        guard [SwiftSyntax.SyntaxKind.classDecl, .structDecl].contains(declaration.kind) else {
            throw MacroDiagnostics.errorMacroUsage(message: "Can only be applied to a struct or class")
        }
        let identifier = (declaration as? StructDeclSyntax)?.identifier ?? (declaration as? ClassDeclSyntax)?.identifier ?? ""
        var override = ""
        if let inheritedTypes = (declaration as? ClassDeclSyntax)?.inheritanceClause?.inheritedTypeCollection,
           inheritedTypes.contains(where: { inherited in inherited.typeName.trimmedDescription == "NSObject" }) {
            override = "override "
        }

        let initializer = try InitializerDeclSyntax("private \(raw: override)init()") {}

        let selfToken: TokenSyntax = "\(raw: identifier.text)()"
        let initShared = FunctionCallExprSyntax(calledExpression: IdentifierExprSyntax(identifier: selfToken)) {}
        let sharedInitializer = InitializerClauseSyntax(equal: .equalToken(trailingTrivia: .space),
                                                        value: initShared)

        let staticToken: TokenSyntax = "static"
        let staticModifier = DeclModifierSyntax(name: staticToken)
        var modifiers = ModifierListSyntax([staticModifier])

        let isPublicACL = declaration.modifiers.compactMap(\.name.tokenKind.keyword).contains(.public) ?? false
        if isPublicACL {
            let publicToken: TokenSyntax = "public"
            let publicModifier = DeclModifierSyntax(name: publicToken)
            modifiers = modifiers.inserting(publicModifier, at: 0)
        }

        let shared = VariableDeclSyntax(modifiers: modifiers,
                                        .let, name: "shared",
                                        initializer: sharedInitializer)

        return [DeclSyntax(initializer),
                DeclSyntax(shared)]
    }
}

extension TokenKind {
    var keyword: Keyword? {
        switch self {
        case let .keyword(keyword): return keyword
        default: return nil
        }
    }
}
