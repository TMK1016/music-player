# Complete English translation of the initial request

Date: 2026-10-24. This is a faithful translation of the user's initial request, including the intent of the attached reference. It is not a statement that every requested capability has been approved by a platform or is technically feasible. “Music Player” is a working name introduced for organization, not a final product name.

## Workspace and working principles

I have already created a local folder named Orca to store my projects. It may contain multiple projects, and I intend to continue using it as my project workspace in the future. I may install different skills and other resources. Please organize and categorize everything appropriately when saving it.

After understanding what I mean in Chinese, translate my ideas completely into English, primarily because I expect this may help produce more precise answers. Then translate your response into Traditional Chinese, not Simplified Chinese.

For now, I would like to use mainstream Rust syntax and practices. If you have better suggestions for other aspects, please propose them.

I want professional, rational answers. Do not give me speculative or hallucinated answers, and do not give me incorrect answers merely to agree with me. Act as an expert who helps me understand different fields, and make sure you understand the relevant subject matter sufficiently before answering. You may record these preferences in a file named TMK準則.md. Refine future responses based on my stated requirements, and make the principles easy for me to review and modify later.

## First project: a music player

My first project is a music player. Its main functions should include music playback and an equalizer. I want good-quality audio sources and detailed sound adjustment, primarily for use in a car. I also want surround effects and other audio effects so that the car's sound system can perform as well as possible.

Development will primarily take place on a Mac. I would like to package the project as downloadable software. If it succeeds and receives a positive response, I may later publish it on Apple's App Store for others to download.

My car currently has component speakers in the front, with separate tweeters and mid-bass drivers, and coaxial speakers in the rear. I therefore want DSP-like functionality to optimize the system. In the future, users should be able to select modes for different sound-system configurations. For example, a car with sixteen speakers should have suitable tuning and configuration options.

Please first consolidate all of my requirements and provide a complete development roadmap. The attached image is the best example I have seen so far: it lets me understand each node's tasks and quickly make changes when needed. Please give me a similar structure.

## Music sources and offline workflow

The music sources I have in mind are local files, YouTube Music, and iCloud cloud storage.

Previously, whenever I found a song I liked on YouTube, I had to copy its URL on my computer, visit a particular website to download the audio, and then import it into my phone before I could listen to it. I want to build an offline player and simplify that workflow: I want to download music directly inside the program and automatically add it to a playlist.

## Attached reference: translated text and design intent

For small things, I ask AI to show me a quick ASCII representation; it is very convenient.

Separately, I built a flow inspector to manage workflows. Every step is connected to its implementation, so I can immediately see which step failed or stopped working. The AI can repair the broken node directly. If the flow itself needs to change, it must discuss that change with me. The image below is an example.

The visual reference shows a dark flow-inspection interface with a workflow list on the left, a node-and-edge graph in the center, and a detailed inspector on the right. Exact small-text node labels in the screenshot are not treated as project requirements because they cannot be read reliably at the supplied resolution.

## Separate follow-up instruction

The user subsequently requested: `brew install gh` — install GitHub CLI using Homebrew. Execution was attempted, but `brew` was not found in PATH or the two standard installation locations. No installation was completed.

The user then requested: “Please install Homebrew for me.” The Mac was identified as Apple Silicon with Xcode available. The shell could not resolve the official installer download host, and the standard Homebrew prefix is outside the environment's writable roots. Homebrew and GitHub CLI remain uninstalled.
