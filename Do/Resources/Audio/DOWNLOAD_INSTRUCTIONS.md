# Meditation Audio Files - Download Instructions

## Quick Download Guide

Most free audio sources require manual browser downloads. Follow these steps:

### Step 1: Best Sources for Ambient Nature Sounds

**Recommended (in order):**

1. **Pixabay Sound Effects** (No account needed, CC0 license)
   🌐 https://pixabay.com/sound-effects/
   - Has actual nature sounds (ocean, rain, forest, etc.)
   - Free commercial use, no attribution required

2. **Freesound.org** (Requires free account, CC0/CC licensed)
   🌐 https://freesound.org/
   - Best quality nature sounds
   - Filter by CC0 license for no attribution needed

3. **Free Sounds Library** (No account needed)
   🌐 https://www.freesoundslibrary.com/
   - Nature sounds and ambience

4. **Zapsplat** (Free account required)
   🌐 https://www.zapsplat.com/
   - Professional quality nature sounds

### Step 2: Download Required Files

For each file, search these sources and download:

#### Ocean Waves (3 files needed)
1. **ambient_ocean.mp3** - Main ocean waves track
   - Pixabay: https://pixabay.com/sound-effects/search/ocean%20waves/
   - Freesound: Search "ocean waves" (filter: CC0, length: 30s-5min)
   - Look for: 2-5 minute seamless loops

2. **ambient_ocean_gentle.mp3** - Gentle, calm waves
   - Pixabay: Search "gentle ocean waves" or "calm ocean"
   - Freesound: Search "gentle ocean" (filter: CC0)

3. **ambient_ocean_rhythmic.mp3** - Stronger rhythmic waves
   - Pixabay: Search "rhythmic ocean" or "strong waves"
   - Freesound: Search "ocean waves rhythmic" (filter: CC0)

#### Rain (3 files needed)
1. **ambient_rain.mp3** - Main rain track (steady rain)
   - Pixabay: https://pixabay.com/sound-effects/search/rain/
   - Freesound: Search "rain loop" (filter: CC0, length: 30s-5min)
   - Look for: Steady, consistent rain

2. **ambient_rain_light.mp3** - Light drizzle
   - Pixabay: Search "light rain" or "drizzle"
   - Freesound: Search "light rain" (filter: CC0)

3. **ambient_rain_steady.mp3** - Steady consistent rain
   - Pixabay: Search "steady rain" or "heavy rain"
   - Freesound: Search "steady rain loop" (filter: CC0)

#### Forest (3 files needed)
1. **ambient_forest.mp3** - Main forest ambience
   - Pixabay: https://pixabay.com/sound-effects/search/forest/
   - Freesound: Search "forest ambience" (filter: CC0, length: 30s-5min)
   - Look for: General forest atmosphere

2. **ambient_forest_birds.mp3** - Forest with bird sounds
   - Pixabay: Search "forest birds" or "birds nature"
   - Freesound: Search "forest birds" (filter: CC0)

3. **ambient_forest_nature.mp3** - General nature sounds
   - Pixabay: Search "nature sounds" or "forest nature"
   - Freesound: Search "nature ambience" (filter: CC0)

#### Zen (3 files needed)
1. **ambient_zen.mp3** - Main zen/meditation ambience
   - Pixabay: https://pixabay.com/sound-effects/search/meditation/
   - Freesound: Search "meditation ambient" or "zen sounds" (filter: CC0)
   - Alternative: Can use gentle nature sounds if zen-specific not available

2. **ambient_zen_bowls.mp3** - Singing bowls
   - Freesound: Search "singing bowl" or "tibetan bowl" (filter: CC0)
   - Look for: Long, sustained tones

3. **ambient_zen_chimes.mp3** - Gentle chimes
   - Freesound: Search "zen chimes" or "meditation chimes" (filter: CC0)
   - Alternative: Wind chimes if zen chimes not available

#### Noise (3 files needed)
1. **ambient_noise_white.mp3** - White noise (full spectrum)
   - Freesound: Search "white noise" (filter: CC0)
   - Or: Generate online (many free white noise generators)

2. **ambient_noise_brown.mp3** - Brown noise (warmer, lower frequencies)
   - Freesound: Search "brown noise" (filter: CC0)
   - Alternative: Can skip if not available

3. **ambient_noise_pink.mp3** - Pink noise (balanced)
   - Freesound: Search "pink noise" (filter: CC0)
   - Alternative: Can skip if not available

### Step 3: File Requirements

When downloading, ensure:
- ✅ Format: MP3
- ✅ Duration: 1-5 minutes (seamless loops preferred)
- ✅ Quality: 44.1kHz, 128-192 kbps
- ✅ Volume: Normalized (no clipping)

### Step 4: Add to Xcode Project

1. Open your Xcode project
2. Right-click on "Do." folder → "New Group" → Name it "AmbientSounds"
3. Drag all downloaded MP3 files into the AmbientSounds folder
4. In the dialog, check "Copy items if needed"
5. Ensure your app target is checked
6. Click "Finish"

### Step 5: Verify Files

After adding files:
1. Build the project
2. Check that files appear in "Build Phases" → "Copy Bundle Resources"
3. Run the app and start a meditation
4. Check console for: "🔊 [AmbientAudio] {type} started from file: {filename}"

## Quick Start (Minimum Files)

If you want to start with just the essentials:

Download these 5 files:
- ambient_ocean.mp3
- ambient_rain.mp3
- ambient_zen.mp3
- ambient_forest.mp3
- ambient_noise_white.mp3

These will cover all meditation types!

## Search Tips

### Pixabay Sound Effects
1. Go to: https://pixabay.com/sound-effects/
2. Use search bar for: "ocean waves", "rain", "forest", etc.
3. Filter by: Free, Sound Effects (not Music)
4. Look for: Long duration files (30 seconds to 5 minutes)
5. Download: Click download button, choose MP3 format

### Freesound.org
1. Create free account: https://freesound.org/help/about/
2. Search for nature sounds
3. **Important:** Filter by "CC0" license (no attribution needed)
4. Look for files 30 seconds to 5 minutes long
5. Download: Click download button after logging in

### Finding Loopable Files
- Look for files described as "loop" or "seamless"
- Longer files (2-5 minutes) loop better
- Test in audio player before adding to project

## Notes

- Pixabay is recommended because: FREE, No attribution needed, High quality, Easy download
- Files should loop seamlessly (test before adding)
- The app will randomly select variants when multiple files exist
- If files aren't found, the app uses programmatic generation as fallback
