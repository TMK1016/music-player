# Orca workspace instructions

Orca is the user's integrated, multi-model project workspace, not the name of an individual product.

Read `TMK準則.md` first. It contains workspace-wide communication, verification and organization rules. Keep independent projects under `projects/<project-slug>/`; read each project's `AGENTS.md` before editing that project. Project-specific implementation decisions belong inside that project, not in these workspace-wide instructions.

Projects: `projects/music-player/` (Music Player, first project) and `projects/project-manager/` (Project Manager, second project; planning only). Its instructions, source, notes, flowchart, journal and deliverables live there. Keep cross-project skills/templates in `shared/`, unclassified input in `inbox/`, and explicitly archived work in `archive/`. Do not move unrelated `Github/` or `test/` content without a concrete request.

Preserve user-authored notes and existing data. Update project indexes and links after moving project files. Keep migration/compatibility identifiers separate from display names.

GitHub backup is a standing user requirement: maintain a separate Git repository for each project, default to a private GitHub repository, commit meaningful completed changes and push updates without repeatedly asking. Exclude secrets, local signing/account config, private user media and rebuildable caches. Verify the remote commit before reporting synchronization. If blocked, retain local commits/bundles and report pending push; never force-push. See TMK準則.md.
