# Mobile-first development loop

The source of truth is the Godot project in GitHub. iPhone is the play-test device, not the editor.

## Loop

1. Change Godot source.
2. Push to `main`.
3. GitHub Actions installs the pinned Godot version and official export templates.
4. The workflow exports the `Web` preset.
5. The generated Web build is uploaded as a workflow artifact.
6. When a public preview host is connected, open that URL in iPhone Safari and play-test.
7. Feed bugs, UX issues, screenshots and gameplay feedback back into the next change.

## Important

- Web preview is for rapid real-device testing.
- Native iOS behavior still needs an iOS export before release.
- App Store submission remains a separate release step.
- Do not treat a successful Web export as proof that iOS native export works.
