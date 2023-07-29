package.path  = 'lualibs/?.lua;lualibs/?/?.lua;lualibs/?/init.lua;' .. package.path

local logger = Logger.create("audio")

local _M = {}

local ffi = require("ffi")

ffi.cdef[[
typedef void (*AudioCallback)(void *bufferData, unsigned int frames);

// Wave, audio wave data
typedef struct Wave {
    unsigned int frameCount;    // Total number of frames (considering channels)
    unsigned int sampleRate;    // Frequency (samples per second)
    unsigned int sampleSize;    // Bit depth (bits per sample): 8, 16, 32 (24 not supported)
    unsigned int channels;      // Number of channels (1-mono, 2-stereo, ...)
    void *data;                 // Buffer data pointer
} Wave;

// Opaque structs declaration
typedef struct rAudioBuffer rAudioBuffer;
typedef struct rAudioProcessor rAudioProcessor;

// AudioStream, custom audio stream
typedef struct AudioStream {
    rAudioBuffer *buffer;       // Pointer to internal data used by the audio system
    rAudioProcessor *processor; // Pointer to internal data processor, useful for audio effects

    unsigned int sampleRate;    // Frequency (samples per second)
    unsigned int sampleSize;    // Bit depth (bits per sample): 8, 16, 32 (24 not supported)
    unsigned int channels;      // Number of channels (1-mono, 2-stereo, ...)
} AudioStream;

// Sound
typedef struct Sound {
    AudioStream stream;         // Audio stream
    unsigned int frameCount;    // Total number of frames (considering channels)
} Sound;

// Music, audio stream, anything longer than ~10 seconds should be streamed
typedef struct Music {
    AudioStream stream;         // Audio stream
    unsigned int frameCount;    // Total number of frames (considering channels)
    bool looping;               // Music looping enable

    int ctxType;                // Type of music context (audio filetype)
    void *ctxData;              // Audio context data, depends on type
} Music;

//----------------------------------------------------------------------------------
// Module Functions Declaration
//----------------------------------------------------------------------------------

// Audio device management functions
void InitAudioDevice(void);                                     // Initialize audio device and context
void CloseAudioDevice(void);                                    // Close the audio device and context
bool IsAudioDeviceReady(void);                                  // Check if audio device has been initialized successfully
void SetMasterVolume(float volume);                             // Set master volume (listener)

// Wave/Sound loading/unloading functions
Wave LoadWave(const char *fileName);                            // Load wave data from file
Wave LoadWaveFromMemory(const char *fileType, const unsigned char *fileData, int dataSize); // Load wave from memory buffer, fileType refers to extension: i.e. ".wav"
bool IsWaveReady(Wave wave);                                    // Checks if wave data is ready
Sound LoadSound(const char *fileName);                          // Load sound from file
Sound LoadSoundFromWave(Wave wave);                             // Load sound from wave data
bool IsSoundReady(Sound sound);                                 // Checks if a sound is ready
void UpdateSound(Sound sound, const void *data, int samplesCount);// Update sound buffer with new data
void UnloadWave(Wave wave);                                     // Unload wave data
void UnloadSound(Sound sound);                                  // Unload sound
bool ExportWave(Wave wave, const char *fileName);               // Export wave data to file, returns true on success
bool ExportWaveAsCode(Wave wave, const char *fileName);         // Export wave sample data to code (.h), returns true on success

// Wave/Sound management functions
void PlaySound(Sound sound);                                    // Play a sound
void StopSound(Sound sound);                                    // Stop playing a sound
void PauseSound(Sound sound);                                   // Pause a sound
void ResumeSound(Sound sound);                                  // Resume a paused sound
bool IsSoundPlaying(Sound sound);                               // Check if a sound is currently playing
void SetSoundVolume(Sound sound, float volume);                 // Set volume for a sound (1.0 is max level)
void SetSoundPitch(Sound sound, float pitch);                   // Set pitch for a sound (1.0 is base level)
void SetSoundPan(Sound sound, float pan);                       // Set pan for a sound (0.0 to 1.0, 0.5=center)
Wave WaveCopy(Wave wave);                                       // Copy a wave to a new wave
void WaveCrop(Wave *wave, int initSample, int finalSample);     // Crop a wave to defined samples range
void WaveFormat(Wave *wave, int sampleRate, int sampleSize, int channels);  // Convert wave data to desired format
float *LoadWaveSamples(Wave wave);                              // Load samples data from wave as a floats array
void UnloadWaveSamples(float *samples);                         // Unload samples data loaded with LoadWaveSamples()

// Music management functions
Music LoadMusicStream(const char *fileName);                    // Load music stream from file
Music LoadMusicStreamFromMemory(const char *fileType, const unsigned char* data, int dataSize); // Load music stream from data
bool IsMusicReady(Music music);                                 // Checks if a music stream is ready
void UnloadMusicStream(Music music);                            // Unload music stream
void PlayMusicStream(Music music);                              // Start music playing
bool IsMusicStreamPlaying(Music music);                         // Check if music is playing
void UpdateMusicStream(Music music);                            // Updates buffers for music streaming
void StopMusicStream(Music music);                              // Stop music playing
void PauseMusicStream(Music music);                             // Pause music playing
void ResumeMusicStream(Music music);                            // Resume playing paused music
void SeekMusicStream(Music music, float position);              // Seek music to a position (in seconds)
void SetMusicVolume(Music music, float volume);                 // Set volume for music (1.0 is max level)
void SetMusicPitch(Music music, float pitch);                   // Set pitch for a music (1.0 is base level)
void SetMusicPan(Music sound, float pan);                       // Set pan for a music (0.0 to 1.0, 0.5=center)
float GetMusicTimeLength(Music music);                          // Get music time length (in seconds)
float GetMusicTimePlayed(Music music);                          // Get current music time played (in seconds)

// AudioStream management functions
AudioStream LoadAudioStream(unsigned int sampleRate, unsigned int sampleSize, unsigned int channels); // Load audio stream (to stream raw audio pcm data)
bool IsAudioStreamReady(AudioStream stream);                    // Checks if an audio stream is ready
void UnloadAudioStream(AudioStream stream);                     // Unload audio stream and free memory
void UpdateAudioStream(AudioStream stream, const void *data, int samplesCount); // Update audio stream buffers with data
bool IsAudioStreamProcessed(AudioStream stream);                // Check if any audio stream buffers requires refill
void PlayAudioStream(AudioStream stream);                       // Play audio stream
void PauseAudioStream(AudioStream stream);                      // Pause audio stream
void ResumeAudioStream(AudioStream stream);                     // Resume audio stream
bool IsAudioStreamPlaying(AudioStream stream);                  // Check if audio stream is playing
void StopAudioStream(AudioStream stream);                       // Stop audio stream
void SetAudioStreamVolume(AudioStream stream, float volume);    // Set volume for audio stream (1.0 is max level)
void SetAudioStreamPitch(AudioStream stream, float pitch);      // Set pitch for audio stream (1.0 is base level)
void SetAudioStreamPan(AudioStream strean, float pan);          // Set pan for audio stream  (0.0 to 1.0, 0.5=center)
void SetAudioStreamBufferSizeDefault(int size);                 // Default size for new audio streams
void SetAudioStreamCallback(AudioStream stream, AudioCallback callback);  // Audio thread callback to request new data

void AttachAudioStreamProcessor(AudioStream stream, AudioCallback processor); // Attach audio stream processor to stream
void DetachAudioStreamProcessor(AudioStream stream, AudioCallback processor); // Detach audio stream processor from stream

void AttachAudioMixedProcessor(AudioCallback processor); // Attach audio stream processor to the entire audio pipeline
void DetachAudioMixedProcessor(AudioCallback processor); // Detach audio stream processor from the entire audio pipeline
]]

ffi = require("ffi")
ffi.cdef([[
typedef int BOOL;
typedef unsigned long DWORD;
typedef long LONG;
 typedef __int64 LONGLONG; 
typedef union _LARGE_INTEGER {
  struct {
    DWORD LowPart;
    LONG  HighPart;
  };
  struct {
    DWORD LowPart;
    LONG  HighPart;
  } u;
  LONGLONG QuadPart;
} LARGE_INTEGER, *PLARGE_INTEGER;
BOOL QueryPerformanceCounter(
  LARGE_INTEGER *lpPerformanceCount
);
BOOL QueryPerformanceFrequency(
  LARGE_INTEGER *lpFrequency
);
]])
local t, f, C = ffi.new("LARGE_INTEGER"), ffi.new("LARGE_INTEGER"), ffi.C
local tonumber = tonumber

local sounds = {}

local function clock()
    C.QueryPerformanceCounter(t)
    C.QueryPerformanceFrequency(f)

    return tonumber(t.QuadPart) / tonumber(f.QuadPart)
end

local LIBDIR = "bin/clibs/"
local audio = ffi.load(LIBDIR .. "raudio.dll")

local function init()
  audio.InitAudioDevice()
  return audio.IsAudioDeviceReady()
end

local function destroy()
  for k, v in pairs(sounds) do
    if audio.IsSoundPlaying(v.sound) then
      audio.StopSound(v.sound)
      audio.UnloadSound(v.sound)
      v.sound = nil
    end
  end
  audio.CloseAudioDevice()
end

local function loadSound(filename, volume)
  local w = ffi.gc(audio.LoadSound(filename), audio.UnloadSound)
  if volume then
    audio.SetSoundVolume(w, volume)
  end
  return audio.IsSoundReady(w), w
end

local function play(sound)
  audio.PlaySound(sound)
end

-- suspendable if nowait
local function loadAndPlay(filename, volume, nowait)
  local s = audio.LoadSound(filename)
  if s and audio.IsSoundReady(s) then
    if volume and volume > 0 and volume <= 1 then
      audio.SetSoundVolume(volume)
    end
    C.QueryPerformanceCounter(t)
    local id = tostring(t.QuadPart)
    local data = {
      sound = s
    }
    if not nowait then
      local this, main_thread = coroutine.running()
      if main_thread then
          logger.err("Can't use suspendable 'doGet' from non-coroutine", debug.traceback())
          audio.UnloadSound(s)
          s = nil
          return false
      end
      data.cont = this
      sounds[id] = data
      logger.log("adding sound", id)
      audio.PlaySound(s)
      coroutine.yield()
    else
      sounds[id] = data
      logger.log("adding sound", id)
      audio.PlaySound(s)
    end
    return true
  else
    logger.err("failed to load sound")
    return nil
  end
end

local function dispatch()
  for j, v in pairs(sounds) do
    if not audio.IsSoundPlaying(v.sound) then
      logger.log("removing sound", j)
      audio.UnloadSound(v.sound)
      v.sound = nil
      sounds[j] = nil
      if v.cont then
        coroutine.resume(v.cont)
      end
    end
  end
end

_M.init = init
_M.destroy = destroy
_M.loadSound = loadSound
_M.play = play
_M.dispatch = dispatch
_M.loadAndPlay = loadAndPlay

return _M
