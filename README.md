![Flutter + GetX .agents](https://raw.githubusercontent.com/hautvfami/.agents/58e70b3601d17521f937ae69ad6be164a7056247/images/flutter-getx-agents-banner.svg)

# Flutter Skills

This repository contains reusable skills and architecture rules for Flutter projects, including structure, design system, localization, deep linking, storage, bootstrap, and coding conventions.

## Usage with `git submodule`

Inside your Flutter project, add this repository under `.agents`:

```bash
git submodule add git@github.com:hautvfami/.agents.git .agents
```

Then initialize and update the submodule:

```bash
git submodule update --init --recursive
```

If you clone a project that already includes the submodule:

```bash
git clone --recurse-submodules <your-flutter-project-git>
```

Or, if you already cloned the project:

```bash
git submodule update --init --recursive
```

## Updating the Skills

Go into the submodule and pull the latest changes:

```bash
cd .agents
git pull origin main
```

Then return to the Flutter project and commit the updated submodule reference:

```bash
cd ..
git add .agents
git commit -m "chore: update flutter skills submodule"
```

## Recommended Structure

```text
your_flutter_project/
  .agents/
  lib/
  pubspec.yaml
```

## Notes

- Use this repository as a shared source of skills and rules across multiple Flutter projects.
- Keep `.agents` at the project root for easier management.
- When new rules or skills are added, update the submodule to sync them into the project.
- One major advantage of using `git submodule` is that you can improve the skills while working inside a real project, push those changes back to the shared repository, and then sync the same improvements across other projects.
