# NoteIt

A simple note taking app.

- GTK4 styling
- Uses plain markdown files for notes
- Color themes
- Minimal

## Building

### Prerequisites

Packages needed:

```
flutter
rustup
python3
unzip
flatpak-builder
```

To setup the environment to build a flatpak run:

```bash
git clone https://github.com/TheAppgineer/flatpak-flutter
cd flatpak-flutter
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Then create a folder for the app

```bash
mkdir onl.anything.noteit
cd onl.anything.noteit
```

Finally create the manifest for the build and build the flatpak app.

```bash
../flatpak-flutter.py --template https://github.com/reimeri/flutter-notes --id onl.anything.noteit --command noteit flatpak-flutter.yml
flatpak-builder --repo=repo --force-clean --sandbox --user --install --install-deps-from=flathub build onl.anything.noteit.yml
```

Optionally test that the app works:

```bash
flatpak run onl.anything.NoteIt --user
```
