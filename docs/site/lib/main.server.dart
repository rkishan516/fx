/// The entrypoint for the **server** environment.
///
/// The [main] method will only be executed on the server during pre-rendering.
/// To run code on the client, check the `main.client.dart` file.
library;

// Server-specific Jaspr import.
import 'package:jaspr/server.dart';

import 'package:jaspr_content/components/callout.dart';
import 'package:jaspr_content/components/github_button.dart';
import 'package:jaspr_content/components/header.dart';
import 'package:jaspr_content/components/image.dart';
import 'package:jaspr_content/components/sidebar.dart';
import 'package:jaspr_content/components/theme_toggle.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:jaspr_content/theme.dart';

// This file is generated automatically by Jaspr, do not remove or edit.
import 'main.server.options.dart';

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(
    ContentApp(
      templateEngine: MustacheTemplateEngine(),
      parsers: [MarkdownParser()],
      extensions: [HeadingAnchorsExtension(), TableOfContentsExtension()],
      components: [Callout(), Image(zoom: true)],
      layouts: [
        DocsLayout(
          header: Header(
            title: 'fx',
            logo: '/images/logo-icon.svg',
            items: [
              ThemeToggle(),
              GitHubButton(repo: 'rkishan516/fx'),
            ],
          ),
          sidebar: Sidebar(
            groups: [
              SidebarGroup(
                title: 'Getting Started',
                links: [
                  SidebarLink(text: 'Overview', href: '/'),
                  SidebarLink(
                    text: 'Introduction',
                    href: '/getting-started/intro',
                  ),
                  SidebarLink(
                    text: 'Installation',
                    href: '/getting-started/installation',
                  ),
                  SidebarLink(
                    text: 'Add to Existing Project',
                    href: '/getting-started/add-to-existing',
                  ),
                  SidebarLink(
                    text: 'Editor Integration',
                    href: '/getting-started/editor-integration',
                  ),
                  SidebarLink(
                    text: 'Tutorial',
                    href: '/getting-started/tutorial',
                  ),
                ],
              ),
              SidebarGroup(
                title: 'Features',
                links: [
                  SidebarLink(text: 'Run Tasks', href: '/features/run-tasks'),
                  SidebarLink(
                    text: 'Cache Task Results',
                    href: '/features/cache-task-results',
                  ),
                  SidebarLink(
                    text: 'Explore Your Workspace',
                    href: '/features/explore-your-workspace',
                  ),
                  SidebarLink(
                    text: 'Generate Code',
                    href: '/features/generate-code',
                  ),
                  SidebarLink(
                    text: 'Enforce Module Boundaries',
                    href: '/features/enforce-module-boundaries',
                  ),
                  SidebarLink(
                    text: 'Manage Releases',
                    href: '/features/manage-releases',
                  ),
                  SidebarLink(
                    text: 'Affected Analysis',
                    href: '/features/affected',
                  ),
                  SidebarLink(
                    text: 'Distribute Tasks',
                    href: '/features/distribute-tasks',
                  ),
                  SidebarLink(text: 'Watch Mode', href: '/features/watch-mode'),
                  SidebarLink(
                    text: 'Batch Execution',
                    href: '/features/batch-execution',
                  ),
                ],
              ),
              SidebarGroup(
                title: 'Concepts',
                links: [
                  SidebarLink(
                    text: 'Mental Model',
                    href: '/concepts/mental-model',
                  ),
                  SidebarLink(
                    text: 'How Caching Works',
                    href: '/concepts/how-caching-works',
                  ),
                  SidebarLink(
                    text: 'Task Pipeline Configuration',
                    href: '/concepts/task-pipeline-configuration',
                  ),
                  SidebarLink(text: 'Plugins', href: '/concepts/plugins'),
                  SidebarLink(
                    text: 'Inferred Tasks',
                    href: '/concepts/inferred-tasks',
                  ),
                  SidebarLink(
                    text: 'Types of Configuration',
                    href: '/concepts/configuration',
                  ),
                  SidebarLink(text: 'Executors', href: '/concepts/executors'),
                  SidebarLink(text: 'fx Daemon', href: '/concepts/daemon'),
                ],
              ),
              SidebarGroup(
                title: 'Recipes',
                links: [
                  SidebarLink(
                    text: 'Inputs and Named Inputs',
                    href: '/recipes/inputs-and-named-inputs',
                  ),
                  SidebarLink(
                    text: 'Remote Cache',
                    href: '/recipes/remote-cache',
                  ),
                  SidebarLink(
                    text: 'Environment Variables',
                    href: '/recipes/environment-variables',
                  ),
                  SidebarLink(
                    text: 'Conformance Rules',
                    href: '/recipes/conformance-rules',
                  ),
                  SidebarLink(
                    text: 'Root-Level Scripts',
                    href: '/recipes/root-level-scripts',
                  ),
                  SidebarLink(text: 'CI Setup', href: '/recipes/ci-setup'),
                  SidebarLink(text: 'Adopting fx', href: '/recipes/adopt-fx'),
                  SidebarLink(
                    text: 'Workspace Watching',
                    href: '/recipes/workspace-watching',
                  ),
                ],
              ),
              SidebarGroup(
                title: 'Reference',
                links: [
                  SidebarLink(
                    text: 'CLI Commands',
                    href: '/reference/commands',
                  ),
                  SidebarLink(
                    text: 'Workspace Configuration',
                    href: '/reference/workspace-configuration',
                  ),
                  SidebarLink(
                    text: 'Project Configuration',
                    href: '/reference/project-configuration',
                  ),
                  SidebarLink(text: '.fxignore', href: '/reference/fxignore'),
                  SidebarLink(
                    text: 'Environment Variables',
                    href: '/reference/environment-variables',
                  ),
                  SidebarLink(text: 'Glossary', href: '/reference/glossary'),
                ],
              ),
              SidebarGroup(
                title: 'Extending fx',
                links: [
                  SidebarLink(
                    text: 'Custom Generators',
                    href: '/extending/custom-generators',
                  ),
                  SidebarLink(
                    text: 'Executor Plugins',
                    href: '/extending/executor-plugins',
                  ),
                  SidebarLink(
                    text: 'Conformance Handlers',
                    href: '/extending/conformance-handlers',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      theme: ContentTheme(
        primary: ThemeColor(ThemeColors.sky.$500, dark: ThemeColors.sky.$300),
        background: ThemeColor(
          ThemeColors.slate.$50,
          dark: ThemeColors.zinc.$950,
        ),
        colors: [ContentColors.quoteBorders.apply(ThemeColors.sky.$400)],
      ),
    ),
  );
}
