import Foundation
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct EnumMacro: MemberMacro {
	public static func expansion(
		of node: AttributeSyntax,
		providingMembersOf declaration: some DeclGroupSyntax,
		in context: some MacroExpansionContext
	) throws -> [DeclSyntax] {
		guard let enumDecl: EnumDeclSyntax = declaration.as(EnumDeclSyntax.self) else {
			context.diagnose(Diagnostic(node: declaration.root, message: GodotMacroError.requiresEnum))
			return []
		}

		var rawValue = 0
		let cases = enumDecl.memberBlock.members.flatMap { member -> [(String, Int)] in
			guard let enumCase: EnumCaseDeclSyntax = member.decl.as(EnumCaseDeclSyntax.self) else {
				return []
			}

			return enumCase.elements.map {
				if let value = evaluateIntegerExpression($0.rawValue?.value) {
					rawValue = value
				}

				rawValue += 1
				return ($0.name.text, rawValue - 1)
			}
		}

		generateGdScriptEnum(enumDecl.name.text, cases)

		return []
	}

	private static func evaluateIntegerExpression(_ expr: ExprSyntax?) -> Int? {
		guard let expr = expr else {
			return nil
		}
		
		if let literal = expr.as(IntegerLiteralExprSyntax.self) {
			return Int(literal.literal.text)!
		} else if let negative = expr.as(PrefixOperatorExprSyntax.self), negative.operator.text == "-" {
			if let value = evaluateIntegerExpression(negative.expression) {
				return -value
			} else {
				return nil
			}
		} else {
			return nil
		}
	}

	private static func generateGdScriptEnum(_ name: String, _ cases: [(String, Int)]) {
		let file: String = """
		class_name \(name)

		enum {
		\t\(cases.map { "\(camelToSnakeCase($0.0)) = \($0.1)" }.joined(separator: ",\n\t"))
		}
		"""

		do {
			try FileManager.default.createDirectory(atPath: "Enums", withIntermediateDirectories: true, attributes: nil)
			try file.write(to: URL(fileURLWithPath: "Enums/\(name).gd"), atomically: false, encoding: .utf8)
		} catch {
			print("Error writing file: \(error)")
		}
	}

	private static func camelToSnakeCase(_ string: String) -> String {
		var result = ""
		var first = true
		for char in string {
			if char.isUppercase && !first {
				result.append("_")
			}
			result.append(char.uppercased())
			first = false
		}
		return result
	}
}
