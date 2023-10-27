import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct BuildURL: ExpressionMacro {
    public static func expansion<Node: FreestandingMacroExpansionSyntax,
                                 Context: MacroExpansionContext>(of node: Node,
                                                                 in context: Context) throws -> ExprSyntax {
        guard node.argumentList.count > 0 else {
            throw MacroDiagnostics.errorMacroUsage(message: "Must specify arguments")
        }

        let arguments = node.argumentList.map {
            "\($0.expression)".trimmingCharacters(in: .whitespacesAndNewlines)
        }
      let element = arguments.first { $0.hasPrefix("\"")}
      if let element {
        let urlEscaped = element.trimmingCharacters(in: .urlHostAllowed.inverted)
        let url = URL(string: urlEscaped)
        if url == nil {
          throw MacroDiagnostics.errorMacroUsage(message: "\(element) not valid")
        }
      }

        let expr: ExprSyntax =
        """
        buildURL {
            \(raw: arguments.joined(separator: "\n"))
        }
        """
        return ExprSyntax(expr)
    }
}
