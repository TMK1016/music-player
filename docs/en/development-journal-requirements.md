# Development journal request — complete English translation

2026-10-24.

“Also, after every update, add the results to the interactive flowchart. Add a development journal so I can see what changed and which features were added each time. Put it in the homepage sidebar, and make every change clickable so it takes me to the corresponding location.”

Implementation: maintain a single journal shared by the flow inspector and native app. The flow inspector maps individual changes to nodes, actual files and evidence, preserves deep links and allows reverse lookup from nodes. The app's sidebar exposes the same history with change details and navigation to relevant feature pages. This is manually maintained development history, not automatic runtime monitoring.
