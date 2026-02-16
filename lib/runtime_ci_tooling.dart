/// Shared CI/CD automation tooling for the Pieces monorepo.
///
/// This package provides reusable infrastructure for:
///   - Multi-phase issue triage (Gemini-powered)
///   - Release pipeline automation (changelog, release notes, version detection)
///   - Audit trail management
///   - MCP server configuration
///   - Cross-platform tool installation
///   - Prompt generators for Gemini CLI
///
/// ## Opting In
///
/// Any repository that places a `runtime.ci.config.json` file at its root
/// is considered to have opted into this tooling. The config file defines
/// the repository name, owner, labels, thresholds, agent settings, and more.
///
/// See `templates/runtime.ci.config.json` for a documented template.
library runtime_ci_tooling;

// Triage utilities
export 'src/triage/utils/run_context.dart';
export 'src/triage/utils/gemini_runner.dart';
export 'src/triage/utils/json_schemas.dart';
export 'src/triage/utils/mcp_config.dart';
export 'src/triage/utils/config.dart';

// Triage models
export 'src/triage/models/game_plan.dart';
export 'src/triage/models/investigation_result.dart';
export 'src/triage/models/triage_decision.dart';

// Triage agents -- NOT exported from barrel due to identical top-level names
// (kAgentId, buildTask). Import them directly with `as` prefixes:
//   import 'package:runtime_ci_tooling/src/triage/agents/code_analysis_agent.dart' as code_agent;
//   import 'package:runtime_ci_tooling/src/triage/agents/pr_correlation_agent.dart' as pr_agent;
//   etc.

// Triage phases
export 'src/triage/phases/plan.dart';
export 'src/triage/phases/investigate.dart';
export 'src/triage/phases/act.dart';
export 'src/triage/phases/verify.dart';
export 'src/triage/phases/link.dart';
export 'src/triage/phases/cross_repo_link.dart';
export 'src/triage/phases/pre_release.dart';
export 'src/triage/phases/post_release.dart';

// Generic utilities
export 'src/utils/repo_utils.dart';
export 'src/utils/tool_installers.dart';
