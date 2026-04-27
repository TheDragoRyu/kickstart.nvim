using System.Collections.Immutable;
using System.Linq;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using Microsoft.CodeAnalysis.Diagnostics;
using UnityAnalyzer.Configuration;

namespace UnityAnalyzer.Rules;

[DiagnosticAnalyzer(LanguageNames.CSharp)]
public sealed class ClosureAllocationAnalyzer : DiagnosticAnalyzer
{
    private static readonly DiagnosticDescriptor Rule = new(
        id: DiagnosticIds.ClosureAllocation,
        title: "Closure allocation",
        messageFormat: "Lambda or anonymous method captures '{0}' — display class allocated",
        category: "Performance",
        defaultSeverity: DiagnosticSeverity.Warning,
        isEnabledByDefault: true,
        description: "Lambdas or anonymous methods that capture variables from the enclosing scope generate a hidden display class instance, allocating on the heap. Use a static lambda or refactor to remove the capture.");

    public override ImmutableArray<DiagnosticDescriptor> SupportedDiagnostics => ImmutableArray.Create(Rule);

    public override void Initialize(AnalysisContext context)
    {
        context.ConfigureGeneratedCodeAnalysis(GeneratedCodeAnalysisFlags.None);
        context.EnableConcurrentExecution();

        context.RegisterCompilationStartAction(start =>
        {
            var config = UnityAnalyzerConfig.Load(start.Options);
            if (!config.IsEnabled(DiagnosticIds.ClosureAllocation))
            {
                return;
            }

            start.RegisterSyntaxNodeAction(
                Analyze,
                SyntaxKind.SimpleLambdaExpression,
                SyntaxKind.ParenthesizedLambdaExpression,
                SyntaxKind.AnonymousMethodExpression);
        });
    }

    private static void Analyze(SyntaxNodeAnalysisContext context)
    {
        var node = context.Node;

        if (node is AnonymousFunctionExpressionSyntax fn && fn.Modifiers.Any(SyntaxKind.StaticKeyword))
        {
            return;
        }

        if (node is not ExpressionSyntax expr)
        {
            return;
        }

        DataFlowAnalysis? flow;
        try
        {
            flow = context.SemanticModel.AnalyzeDataFlow(expr);
        }
        catch
        {
            return;
        }

        if (flow is null || !flow.Succeeded || flow.Captured.IsDefaultOrEmpty)
        {
            return;
        }

        var first = flow.Captured[0];
        context.ReportDiagnostic(Diagnostic.Create(Rule, GetReportLocation(node), first.Name));
    }

    private static Location GetReportLocation(SyntaxNode lambda) => lambda switch
    {
        ParenthesizedLambdaExpressionSyntax p => p.ArrowToken.GetLocation(),
        SimpleLambdaExpressionSyntax s => s.ArrowToken.GetLocation(),
        AnonymousMethodExpressionSyntax a => a.DelegateKeyword.GetLocation(),
        _ => lambda.GetLocation(),
    };
}
