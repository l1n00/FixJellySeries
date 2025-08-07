# TV Series Renamer Script for Jellyfin

A comprehensive bash script to automatically rename TV series and episodes according to Jellyfin Media Server conventions.

## 🎯 Key Features

- **Rename season folders**: `S1`, `S01` → `Season 01`
- **Rename episode files**: `E01_Title.mp4` → `Series - s01e01 - Title.mp4`
- **Safe DRY_RUN mode**: Simulate changes before applying them
- **Multiple format support**: Recognizes various naming patterns
- **Colored and detailed output**: Clear feedback during processing
- **Automatic cleanup**: Removes temporary `_tmp` folders
- **Interactive selection**: Process all series or select specific ones

## 📁 Input Formats

The script automatically recognizes:

### Season Folders:
- `S1`, `S01`, `S2`, `S02`...
- `Season 1`, `Season 01`...
- `Stagione 1`, `Stagione 01`... (Italian)

### Episode Files:
- `E01_Title.mp4`
- `E01 Title.mp4`
- `E01-Title.mp4`
- `1x01_Title.mp4`
- `S01E01_Title.mp4`
- `01_Title.mp4`

### Supported Video Extensions:
`mp4`, `mkv`, `avi`, `mov`, `wmv`, `flv`, `webm`, `m4v`

## 📋 Output Format

The script converts everything to Jellyfin-compatible format:

```
Series Name/
├── Season 01/
│   ├── Series Name - s01e01 - Episode Title.mp4
│   ├── Series Name - s01e02 - Episode Title.mp4
│   └── ...
├── Season 02/
│   ├── Series Name - s02e01 - Episode Title.mp4
│   └── ...
└── ...
```

## 🚀 Quick Start

1. **Download the script:**
   ```bash
   git clone https://github.com/l1n00/FixJellySeries.git
   cd FixJellySeries
   chmod +x TV_Series_Renamer.sh
   ./TV_Series_Renamer.sh
   ```

2. **First run (safe mode):**
   ```bash
   ./TV_Series_Renamer.sh
   ```
   The script starts in `DRY_RUN=true` mode - it shows what it would do without making changes.

3. **Apply changes:**
   - Open the script in a text editor
   - Change `DRY_RUN=true` to `DRY_RUN=false`
   - Run the script again

## ⚙️ Configuration

Edit these variables at the top of the script:

```bash
# Base directory (leave empty to be prompted)
BASE_DIR=""

# Safe mode - shows what would happen without making changes
DRY_RUN=true

# Remove temporary download folders
DELETE_TMP_FOLDERS=true

# Show detailed output
VERBOSE=true

# Supported video file extensions
VIDEO_EXTENSIONS="mp4 mkv avi mov wmv flv webm m4v"
```

## 📖 Usage Examples

### Example 1: Process All Series
```bash
$ ./TV_Series_Renamer.sh
Available series:
0) Process ALL series
1) breaking-bad
2) game-of-thrones
3) the-office

Select the number of the series to process: 0
```

### Example 2: Process Single Series
```bash
Select the number of the series to process: 2
[INFO] Selected series: game-of-thrones
```

### Example 3: Before and After
**Before:**
```
game-of-thrones/
├── S1/
│   ├── E01_Winter Is Coming.mp4
│   ├── E02_The Kingsroad.mp4
│   └── E01_Winter Is Coming_tmp/
├── S2/
│   ├── E01_The North Remembers.mp4
│   └── ...
```

**After:**
```
game-of-thrones/
├── Season 01/
│   ├── Game Of Thrones - s01e01 - Winter Is Coming.mp4
│   ├── Game Of Thrones - s01e02 - The Kingsroad.mp4
├── Season 02/
│   ├── Game Of Thrones - s02e01 - The North Remembers.mp4
│   └── ...
```

## 🛡️ Safety Features

- **DRY_RUN Mode**: Test changes safely before applying
- **Backup Recommendation**: Always backup your media before running
- **Error Handling**: Continues processing even if individual files fail
- **Verbose Output**: See exactly what's happening
- **Confirmation Prompts**: Interactive selection of directories and series

## 🔧 Troubleshooting

### Script finds 0 episodes
- Check that your files follow supported naming patterns
- Enable `VERBOSE=true` to see detailed processing
- Verify video file extensions are in `VIDEO_EXTENSIONS`

### Permission errors
```bash
chmod +x TV_Series_Renamer.sh
sudo ./TV_Series_Renamer.sh  # if files are owned by root
```

### Unsupported naming pattern
The script supports most common patterns, but you can modify the regex patterns in the `rename_episode_files()` function.

## 🎬 Jellyfin Integration

After running the script:

1. Open Jellyfin Dashboard
2. Go to **Libraries** → **TV Shows**
3. Click the **three dots** next to your library
4. Select **Scan Library Files**
5. For complete refresh: **Replace All Metadata**

## 📝 Requirements

- **Bash 4.0+** (most Linux distributions and macOS)
- **Standard Unix tools**: `mv`, `ls`, `find`, `grep`, `sed`
- **Permissions**: Read/write access to media directories

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

- Always backup your media files before running this script
- Test with a small subset of files first
- The script modifies file and folder names - use at your own risk
- Not responsible for any data loss or corruption

## 🙋‍♂️ Support

If you encounter issues:

1. Check the troubleshooting section
2. Enable `VERBOSE=true` for detailed output
3. Open an issue with your configuration and error messages
4. Include sample file names that aren't working

---

**Made with ❤️ for the Jellyfin community**