using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using Microsoft.CodeAnalysis.Diagnostics;

namespace UnityAnalyzer.Configuration;

internal sealed class UnityAnalyzerConfig
{
    private static readonly UnityAnalyzerConfig AllEnabled = new(new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase));

    private readonly Dictionary<string, bool> _rules;

    private UnityAnalyzerConfig(Dictionary<string, bool> rules)
    {
        _rules = rules;
    }

    public bool IsEnabled(string ruleId)
    {
        return !_rules.TryGetValue(ruleId, out var enabled) || enabled;
    }

    public static UnityAnalyzerConfig Load(AnalyzerOptions options)
    {
        var file = options.AdditionalFiles.FirstOrDefault(f =>
            !string.IsNullOrEmpty(f.Path) &&
            f.Path.EndsWith(ConfigKeys.FileName, StringComparison.OrdinalIgnoreCase));

        if (file is null)
        {
            return AllEnabled;
        }

        var text = file.GetText(CancellationToken.None);
        if (text is null)
        {
            return AllEnabled;
        }

        var rules = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase);
        foreach (var line in text.Lines)
        {
            var raw = line.ToString().Trim();
            if (raw.Length == 0 || raw[0] == '#')
            {
                continue;
            }

            var eq = raw.IndexOf('=');
            if (eq <= 0)
            {
                continue;
            }

            var key = raw.Substring(0, eq).Trim();
            var value = raw.Substring(eq + 1).Trim();
            if (key.Length == 0)
            {
                continue;
            }

            if (string.Equals(value, "enabled", StringComparison.OrdinalIgnoreCase))
            {
                rules[key] = true;
            }
            else if (string.Equals(value, "disabled", StringComparison.OrdinalIgnoreCase))
            {
                rules[key] = false;
            }
        }

        return new UnityAnalyzerConfig(rules);
    }
}
