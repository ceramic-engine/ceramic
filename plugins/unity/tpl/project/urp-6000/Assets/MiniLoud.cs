#define MINILOUD_RESAMPLER_LINEAR

using System;
using System.Collections.Generic;

// MiniLoud is a C# port of SoLoud's mixer implementation (https://github.com/jarikomppa/soloud).
// The port has been done by Jérémy Faivre, with the help of an LLM to facilitate the language translation.
//
// Original SoLoud notice:
//
// SoLoud contains various third party libraries which vary in licenses,
// but are all extremely liberal; no attribution in binary form is required.
// For more information, see SoLoud manual or http://soloud-audio.com/legal.html
//
// SoLoud proper is licensed under the zlib/libpng license:
//
// SoLoud audio engine
// Copyright (c) 2013-2018 Jari Komppa
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
//    1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
//
//    2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
//
//    3. This notice may not be removed or altered from any source
//    distribution.

namespace MiniLoud
{
    public enum Result
    {
        NO_ERROR = 0,
        INVALID_PARAMETER = 1,
        FILE_NOT_FOUND = 2,
        FILE_LOAD_FAILED = 3,
        DLL_NOT_FOUND = 4,
        OUT_OF_MEMORY = 5,
        NOT_IMPLEMENTED = 6,
        UNKNOWN_ERROR = 7
    }

    public enum Resampler
    {
        POINT = 0,
        LINEAR = 1,
        CATMULLROM = 2
    }

    [Flags]
    public enum MiniloudFlags
    {
        NONE = 0,
        CLIP_ROUNDOFF = 1,
        ENABLE_VISUALIZATION = 2,
        LEFT_HANDED_3D = 4,
        NO_FPU_REGISTER_CHANGE = 8
    }

    public class AlignedFloatBuffer
    {
        public float[] mData;
        public int mFloats;

        public AlignedFloatBuffer()
        {
            mData = null;
            mFloats = 0;
        }

        public Result Init(int aFloats)
        {
            mFloats = aFloats;
            mData = new float[aFloats];
            return Result.NO_ERROR;
        }

        public void Clear()
        {
            if (mData != null)
            {
                Array.Clear(mData, 0, mFloats);
            }
        }
    }

    public class AudioSourceInstance
    {
        [Flags]
        public enum FLAGS
        {
            NONE = 0,
            PAUSED = 1,
            INAUDIBLE = 2,
            DISABLE_AUTOSTOP = 4,
            INAUDIBLE_TICK = 8,
            LOOPING = 16
        }

        public float[] mAudioData;
        public int mAudioDataLength;
        public int mChannels;
        public float mSamplerate;
        public FLAGS mFlags;
        public float mSetVolume;
        public float mSetPan;
        public float mSetRelativePlaySpeed;
        public float mOverallVolume;
        public float mOverallRelativePlaySpeed;
        public float mPan;
        public float[] mChannelVolume;
        public float[] mCurrentChannelVolume;
        public float mStreamTime;
        public double mStreamPosition;
        public float[][] mResampleData;
        public int mSrcOffset;
        public int mLeftoverSamples;
        public int mDelaySamples;
        public float mLoopPoint;
        public int mLoopCount;
        public int mPlayIndex;
        public double mPlayPosition;
        public int mActiveFader;

        public AudioSourceInstance()
        {
            mChannels = 1;
            mSamplerate = 44100.0f;
            mFlags = FLAGS.NONE;
            mSetVolume = 1.0f;
            mSetPan = 0.0f;
            mSetRelativePlaySpeed = 1.0f;
            mOverallVolume = 1.0f;
            mOverallRelativePlaySpeed = 1.0f;
            mPan = 0.0f;
            mChannelVolume = new float[Miniloud.MAX_CHANNELS];
            mCurrentChannelVolume = new float[Miniloud.MAX_CHANNELS];
            mStreamTime = 0.0f;
            mStreamPosition = 0.0;
            mResampleData = new float[2][];
            mSrcOffset = 0;
            mLeftoverSamples = 0;
            mDelaySamples = 0;
            mLoopPoint = 0.0f;
            mLoopCount = 0;
            mPlayIndex = 0;
            mPlayPosition = 0.0;
            mActiveFader = 0;

            // Initialize channel volumes to 1.0
            for (int i = 0; i < Miniloud.MAX_CHANNELS; i++)
            {
                mChannelVolume[i] = 1.0f;
                mCurrentChannelVolume[i] = 1.0f;
            }
        }

        public void SetAudioData(float[] audioData, int channels, float sampleRate)
        {
            mAudioData = audioData;
            mAudioDataLength = audioData.Length;
            mChannels = channels;
            mSamplerate = sampleRate;
        }

        public bool HasEnded()
        {
            return mPlayPosition >= mAudioDataLength / mChannels;
        }

        public int GetAudio(float[] aBuffer, int aSamplesToRead, int aBufferSize)
        {
            if (mAudioData == null || HasEnded())
                return 0;

            int samplesPerChannel = mAudioDataLength / mChannels;
            int currentSample = (int)mPlayPosition;
            int samplesToRead = Math.Min(aSamplesToRead, samplesPerChannel - currentSample);

            if (samplesToRead <= 0)
                return 0;

            // Output in planar format matching MiniLoud
            // Channel data is stored in separate contiguous blocks
            for (int ch = 0; ch < mChannels; ch++)
            {
                for (int i = 0; i < samplesToRead; i++)
                {
                    int sourceIndex = (currentSample + i) * mChannels + ch;
                    if (sourceIndex < mAudioDataLength)
                    {
                        aBuffer[ch * aBufferSize + i] = mAudioData[sourceIndex];
                    }
                    else
                    {
                        aBuffer[ch * aBufferSize + i] = 0.0f;
                    }
                }
            }

            mPlayPosition += samplesToRead;
            return samplesToRead;
        }

        public Result Seek(float seconds, float[] scratchBuffer, int scratchSize)
        {
            if (mAudioData == null)
                return Result.FILE_NOT_FOUND;

            int samplesPerChannel = mAudioDataLength / mChannels;
            int targetSample = (int)(seconds * mSamplerate);

            if (targetSample >= samplesPerChannel)
            {
                if ((mFlags & FLAGS.LOOPING) != 0)
                {
                    targetSample = 0;
                }
                else
                {
                    mPlayPosition = samplesPerChannel;
                    mStreamPosition = seconds;
                    return Result.NO_ERROR;
                }
            }

            mPlayPosition = Math.Max(0, targetSample);
            mStreamPosition = seconds;
            return Result.NO_ERROR;
        }
    }

    public class Miniloud
    {
        public const int VOICE_COUNT = 1024;
        public const int MAX_CHANNELS = 8;
        public const int SAMPLE_GRANULARITY = 512;
        public const int FIXPOINT_FRAC_BITS = 20;
        public const int FIXPOINT_FRAC_MUL = 1 << FIXPOINT_FRAC_BITS;
        public const int FIXPOINT_FRAC_MASK = (1 << FIXPOINT_FRAC_BITS) - 1;

        public float mGlobalVolume;
        public float mPostClipScaler;
        public int mSamplerate;
        public int mBufferSize;
        public int mScratchSize;
        public int mScratchNeeded;
        public int mChannels;
        public int mMaxActiveVoices;
        public int mActiveVoiceCount;
        public int mHighestVoice;
        public bool mActiveVoiceDirty;
        public int[] mActiveVoice;
        public AudioSourceInstance[] mVoice;
        public int mPlayIndex;
        public float mStreamTime;
        public double mLastClockedTime;
        public MiniloudFlags mFlags;
        public AlignedFloatBuffer mScratch;
        public AlignedFloatBuffer mOutputScratch;
        public AlignedFloatBuffer[] mResampleData;
        public AudioSourceInstance[] mResampleDataOwner;

        // Visualization data
        public float[] mVisualizationWaveData;
        public float[] mVisualizationChannelVolume;
        public float[] mWaveData;
        public float[] mFFTData;

        // Pre-allocated buffers
        private int[] mQuicksortStack = new int[24];
        private byte[] mLiveChannelBuffer = new byte[256];
        private float[] mPanBuffer = new float[MAX_CHANNELS];
        private float[] mPanDestBuffer = new float[MAX_CHANNELS];
        private float[] mPanIncrementBuffer = new float[MAX_CHANNELS];

        private readonly object mAudioMutex = new object();

        public Miniloud()
        {
            mGlobalVolume = 1.0f;
            mPostClipScaler = 0.95f;
            mSamplerate = 44100;
            mBufferSize = 2048;
            mChannels = 2;
            mMaxActiveVoices = 16;
            mActiveVoiceCount = 0;
            mHighestVoice = 0;
            mActiveVoiceDirty = true;
            mActiveVoice = new int[VOICE_COUNT];
            mVoice = new AudioSourceInstance[VOICE_COUNT];
            mPlayIndex = 0;
            mStreamTime = 0.0f;
            mLastClockedTime = 0.0;
            mFlags = MiniloudFlags.NONE;
            mScratch = new AlignedFloatBuffer();
            mOutputScratch = new AlignedFloatBuffer();
            mVisualizationWaveData = new float[256];
            mVisualizationChannelVolume = new float[MAX_CHANNELS];
            mWaveData = new float[256];
            mFFTData = new float[256];

            for (int i = 0; i < VOICE_COUNT; i++)
            {
                mActiveVoice[i] = 0;
                mVoice[i] = null;
            }
        }

        public Result Init(int sampleRate = 44100, int bufferSize = 2048, int channels = 2, int maxActiveVoices = 16, MiniloudFlags flags = MiniloudFlags.CLIP_ROUNDOFF)
        {
            mSamplerate = sampleRate;
            mBufferSize = bufferSize;
            mChannels = channels;
            mMaxActiveVoices = maxActiveVoices;
            mFlags = flags;

            // Match MiniLoud's exact scratch size calculation
            mScratchSize = bufferSize;
            if (mScratchSize < SAMPLE_GRANULARITY * 2) mScratchSize = SAMPLE_GRANULARITY * 2;
            if (mScratchSize < 4096) mScratchSize = 4096;
            mScratchNeeded = mScratchSize;

            mScratch.Init(mScratchSize * MAX_CHANNELS);
            mOutputScratch.Init(mScratchSize * MAX_CHANNELS);

            mResampleData = new AlignedFloatBuffer[mMaxActiveVoices * 2];
            mResampleDataOwner = new AudioSourceInstance[mMaxActiveVoices];

            // Initialize resample data exactly like MiniLoud
            for (int i = 0; i < mMaxActiveVoices * 2; i++)
            {
                mResampleData[i] = new AlignedFloatBuffer();
                mResampleData[i].Init(SAMPLE_GRANULARITY * MAX_CHANNELS);
            }

            for (int i = 0; i < mMaxActiveVoices; i++)
                mResampleDataOwner[i] = null;

            return Result.NO_ERROR;
        }

        public int Play(AudioSourceInstance audioSource, float volume = 1.0f, float pan = 0.0f, float pitch = 1.0f, float position = 0.0f, bool paused = false)
        {
            if (audioSource == null)
                return -1;

            lock (mAudioMutex)
            {
                int ch = FindFreeVoice();
                if (ch < 0)
                    return -1;

                mVoice[ch] = audioSource;
                mVoice[ch].mPlayIndex = mPlayIndex++;

                // Initialize current channel volumes to match target volumes
                for (int i = 0; i < MAX_CHANNELS; i++)
                {
                    mVoice[ch].mCurrentChannelVolume[i] = mVoice[ch].mChannelVolume[i];
                }

                SetVoiceVolume_internal(ch, volume);
                SetVoicePan_internal(ch, pan);
                SetVoiceRelativePlaySpeed_internal(ch, pitch);

                if (position != 0.0f)
                {
                    mVoice[ch].Seek(position, mScratch.mData, mScratchSize);
                }

                if (paused)
                    mVoice[ch].mFlags |= AudioSourceInstance.FLAGS.PAUSED;
                else
                    mVoice[ch].mFlags &= ~AudioSourceInstance.FLAGS.PAUSED;

                mActiveVoiceDirty = true;

                if (ch >= mHighestVoice)
                    mHighestVoice = ch + 1;

                return ch;
            }
        }

        private int FindFreeVoice()
        {
            for (int i = 0; i < VOICE_COUNT; i++)
            {
                if (mVoice[i] == null)
                    return i;
            }
            return -1;
        }

        public void SetVoiceVolume(int voiceHandle, float volume)
        {
            lock (mAudioMutex)
            {
                SetVoiceVolume_internal(voiceHandle, volume);
            }
        }

        private void SetVoiceVolume_internal(int voiceHandle, float volume)
        {
            if (voiceHandle < 0 || voiceHandle >= VOICE_COUNT || mVoice[voiceHandle] == null)
                return;

            mVoice[voiceHandle].mSetVolume = volume;
            UpdateVoiceVolume_internal(voiceHandle);
            mActiveVoiceDirty = true;
        }

        private void UpdateVoiceVolume_internal(int voiceHandle)
        {
            mVoice[voiceHandle].mOverallVolume = mVoice[voiceHandle].mSetVolume * mGlobalVolume;
        }

        public void SetVoicePan(int voiceHandle, float pan)
        {
            lock (mAudioMutex)
            {
                SetVoicePan_internal(voiceHandle, pan);
            }
        }

        private void SetVoicePan_internal(int voiceHandle, float pan)
        {
            if (voiceHandle < 0 || voiceHandle >= VOICE_COUNT || mVoice[voiceHandle] == null)
                return;

            mVoice[voiceHandle].mPan = pan;

            // Exact MiniLoud panning calculation
            for (int i = 0; i < MAX_CHANNELS; i++)
                mVoice[voiceHandle].mChannelVolume[i] = 1.0f;

            if (mChannels >= 2)
            {
                float left = 1.0f;
                float right = 1.0f;

                if (pan > 0)
                    left = 1.0f - pan;
                else if (pan < 0)
                    right = 1.0f + pan;

                mVoice[voiceHandle].mChannelVolume[0] = left;
                mVoice[voiceHandle].mChannelVolume[1] = right;
            }
        }

        public void SetVoiceRelativePlaySpeed(int voiceHandle, float speed)
        {
            lock (mAudioMutex)
            {
                SetVoiceRelativePlaySpeed_internal(voiceHandle, speed);
            }
        }

        private void SetVoiceRelativePlaySpeed_internal(int voiceHandle, float speed)
        {
            if (voiceHandle < 0 || voiceHandle >= VOICE_COUNT || mVoice[voiceHandle] == null)
                return;

            mVoice[voiceHandle].mSetRelativePlaySpeed = speed;
            mVoice[voiceHandle].mOverallRelativePlaySpeed = speed;
        }

        public void SetVoicePause(int voiceHandle, bool paused)
        {
            lock (mAudioMutex)
            {
                SetVoicePause_internal(voiceHandle, paused);
            }
        }

        private void SetVoicePause_internal(int voiceHandle, bool paused)
        {
            if (voiceHandle < 0 || voiceHandle >= VOICE_COUNT || mVoice[voiceHandle] == null)
                return;

            if (paused)
                mVoice[voiceHandle].mFlags |= AudioSourceInstance.FLAGS.PAUSED;
            else
                mVoice[voiceHandle].mFlags &= ~AudioSourceInstance.FLAGS.PAUSED;

            mActiveVoiceDirty = true;
        }

        public void StopVoice(int voiceHandle)
        {
            lock (mAudioMutex)
            {
                StopVoice_internal(voiceHandle);
            }
        }

        private void StopVoice_internal(int voiceHandle)
        {
            if (voiceHandle < 0 || voiceHandle >= VOICE_COUNT || mVoice[voiceHandle] == null)
                return;

            mVoice[voiceHandle] = null;
            mActiveVoiceDirty = true;
        }

        public void StopAll()
        {
            lock (mAudioMutex)
            {
                for (int i = 0; i < VOICE_COUNT; i++)
                {
                    StopVoice_internal(i);
                }
            }
        }

        public float GetVoiceVolume(int voiceHandle)
        {
            lock (mAudioMutex)
            {
                if (voiceHandle < 0 || voiceHandle >= VOICE_COUNT || mVoice[voiceHandle] == null)
                    return 0.0f;
                return mVoice[voiceHandle].mSetVolume;
            }
        }

        public float GetVoicePan(int voiceHandle)
        {
            lock (mAudioMutex)
            {
                if (voiceHandle < 0 || voiceHandle >= VOICE_COUNT || mVoice[voiceHandle] == null)
                    return 0.0f;
                return mVoice[voiceHandle].mPan;
            }
        }

        public float GetVoiceRelativePlaySpeed(int voiceHandle)
        {
            lock (mAudioMutex)
            {
                if (voiceHandle < 0 || voiceHandle >= VOICE_COUNT || mVoice[voiceHandle] == null)
                    return 1.0f;
                return mVoice[voiceHandle].mSetRelativePlaySpeed;
            }
        }

        public double GetVoicePosition(int voiceHandle)
        {
            lock (mAudioMutex)
            {
                if (voiceHandle < 0 || voiceHandle >= VOICE_COUNT || mVoice[voiceHandle] == null)
                    return 0.0;
                // Use mStreamPosition which accounts for pitch, not mPlayPosition
                return mVoice[voiceHandle].mStreamPosition;
            }
        }

        public void SetVoicePosition(int voiceHandle, double position)
        {
            lock (mAudioMutex)
            {
                if (voiceHandle < 0 || voiceHandle >= VOICE_COUNT || mVoice[voiceHandle] == null)
                    return;

                // Set stream position directly
                mVoice[voiceHandle].mStreamPosition = (float)position;

                // Seek to the actual sample position
                mVoice[voiceHandle].Seek((float)position, mScratch.mData, mScratchSize);
            }
        }

        public void Mix(float[] aBuffer, int aSamples)
        {
            Mix_internal(aSamples);
            Array.Copy(mScratch.mData, aBuffer, aSamples * mChannels);
        }

        private void Mix_internal(int aSamples)
        {
            float buffertime = aSamples / (float)mSamplerate;
            mStreamTime += buffertime;
            mLastClockedTime = 0;

            float globalVolume0 = mGlobalVolume;
            float globalVolume1 = mGlobalVolume;

            lock (mAudioMutex)
            {
                // Process voice updates - simplified without faders
                for (int i = 0; i < mHighestVoice; i++)
                {
                    if (mVoice[i] != null && (mVoice[i].mFlags & AudioSourceInstance.FLAGS.PAUSED) == 0)
                    {
                        mVoice[i].mActiveFader = 0;
                        mVoice[i].mStreamTime += buffertime;
                        mVoice[i].mStreamPosition += buffertime * mVoice[i].mOverallRelativePlaySpeed;

                        UpdateVoiceVolume_internal(i);
                    }
                }

                if (mActiveVoiceDirty)
                    CalcActiveVoices_internal();

                // Resize scratch if needed
                if (mScratchSize < mScratchNeeded)
                {
                    mScratchSize = mScratchNeeded;
                    mScratch.Init(mScratchSize * MAX_CHANNELS);
                }

                MixBus_internal(mOutputScratch.mData, aSamples, aSamples, mScratch.mData, mSamplerate, mChannels);
            }

            Clip_internal(mOutputScratch, mScratch, aSamples, globalVolume0, globalVolume1);

            if ((mFlags & MiniloudFlags.ENABLE_VISUALIZATION) != 0)
            {
                for (int i = 0; i < MAX_CHANNELS; i++)
                {
                    mVisualizationChannelVolume[i] = 0;
                }
                if (aSamples > 255)
                {
                    for (int i = 0; i < 256; i++)
                    {
                        mVisualizationWaveData[i] = 0;
                        for (int j = 0; j < mChannels; j++)
                        {
                            float sample = mScratch.mData[i + j * aSamples];
                            float absvol = Math.Abs(sample);
                            if (mVisualizationChannelVolume[j] < absvol)
                                mVisualizationChannelVolume[j] = absvol;
                            mVisualizationWaveData[i] += sample;
                        }
                    }
                }
                else
                {
                    // Very unlikely failsafe branch
                    for (int i = 0; i < 256; i++)
                    {
                        mVisualizationWaveData[i] = 0;
                        for (int j = 0; j < mChannels; j++)
                        {
                            float sample = mScratch.mData[(i % aSamples) + j * aSamples];
                            float absvol = Math.Abs(sample);
                            if (mVisualizationChannelVolume[j] < absvol)
                                mVisualizationChannelVolume[j] = absvol;
                            mVisualizationWaveData[i] += sample;
                        }
                    }
                }
            }
        }

        private void MixBus_internal(float[] aBuffer, int aSamplesToRead, int aBufferSize, float[] aScratch, int aSamplerate, int aChannels)
        {
            // Clear accumulation buffer
            for (int i = 0; i < aSamplesToRead; i++)
            {
                for (int j = 0; j < aChannels; j++)
                {
                    aBuffer[i + j * aBufferSize] = 0;
                }
            }

            // Accumulate sound sources
            for (int i = 0; i < mActiveVoiceCount; i++)
            {
                AudioSourceInstance voice = mVoice[mActiveVoice[i]];
                if (voice != null &&
                    (voice.mFlags & AudioSourceInstance.FLAGS.PAUSED) == 0 &&
                    (voice.mFlags & AudioSourceInstance.FLAGS.INAUDIBLE) == 0)
                {
                    float step = (voice.mSamplerate / aSamplerate) * voice.mOverallRelativePlaySpeed;
                    // avoid step overflow
                    if (step > (1 << (32 - FIXPOINT_FRAC_BITS)))
                        step = 0;
                    int step_fixed = (int)Math.Floor(step * FIXPOINT_FRAC_MUL);
                    int outofs = 0;

                    if (voice.mDelaySamples > 0)
                    {
                        if (voice.mDelaySamples > aSamplesToRead)
                        {
                            outofs = aSamplesToRead;
                            voice.mDelaySamples -= aSamplesToRead;
                        }
                        else
                        {
                            outofs = voice.mDelaySamples;
                            voice.mDelaySamples = 0;
                        }

                        // Clear scratch where we're skipping
                        for (int k = 0; k < voice.mChannels; k++)
                        {
                            Array.Clear(aScratch, k * aBufferSize, outofs);
                        }
                    }

                    while (step_fixed != 0 && outofs < aSamplesToRead)
                    {
                        if (voice.mLeftoverSamples == 0)
                        {
                            // Swap resample buffers (ping-pong)
                            float[] t = voice.mResampleData[0];
                            voice.mResampleData[0] = voice.mResampleData[1];
                            voice.mResampleData[1] = t;

                            // Get a block of source data
                            int readcount = 0;
                            if (!voice.HasEnded() || (voice.mFlags & AudioSourceInstance.FLAGS.LOOPING) != 0)
                            {
                                readcount = voice.GetAudio(voice.mResampleData[0], SAMPLE_GRANULARITY, SAMPLE_GRANULARITY);
                                if (readcount < SAMPLE_GRANULARITY)
                                {
                                    if ((voice.mFlags & AudioSourceInstance.FLAGS.LOOPING) != 0)
                                    {
                                        while (readcount < SAMPLE_GRANULARITY && voice.Seek(voice.mLoopPoint, mScratch.mData, mScratchSize) == Result.NO_ERROR)
                                        {
                                            voice.mLoopCount++;
                                            int inc = voice.GetAudio(voice.mResampleData[0], SAMPLE_GRANULARITY - readcount, SAMPLE_GRANULARITY);
                                            readcount += inc;
                                            if (inc == 0) break;
                                        }
                                    }
                                }
                            }

                            // Clear remaining resample data
                            if (readcount < SAMPLE_GRANULARITY)
                            {
                                for (int k = 0; k < voice.mChannels; k++)
                                {
                                    Array.Clear(voice.mResampleData[0], readcount + SAMPLE_GRANULARITY * k, SAMPLE_GRANULARITY - readcount);
                                }
                            }

                            // Source offset management
                            if (voice.mSrcOffset < SAMPLE_GRANULARITY * FIXPOINT_FRAC_MUL)
                            {
                                voice.mSrcOffset = 0;
                            }
                            else
                            {
                                // We have new block of data, move pointer backwards
                                voice.mSrcOffset -= SAMPLE_GRANULARITY * FIXPOINT_FRAC_MUL;
                            }
                        }
                        else
                        {
                            voice.mLeftoverSamples = 0;
                        }

                        // Calculate output samples
                        int writesamples = 0;

                        if (voice.mSrcOffset < SAMPLE_GRANULARITY * FIXPOINT_FRAC_MUL)
                        {
                            writesamples = ((SAMPLE_GRANULARITY * FIXPOINT_FRAC_MUL) - voice.mSrcOffset) / step_fixed + 1;

                            // avoid reading past the current buffer
                            if (((writesamples * step_fixed + voice.mSrcOffset) >> FIXPOINT_FRAC_BITS) >= SAMPLE_GRANULARITY)
                                writesamples--;
                        }

                        // Output buffer bounds check
                        if (writesamples + outofs > aSamplesToRead)
                        {
                            voice.mLeftoverSamples = (writesamples + outofs) - aSamplesToRead;
                            writesamples = aSamplesToRead - outofs;
                        }

                        // Call resampler
                        if (writesamples > 0)
                        {
                            for (int j = 0; j < voice.mChannels; j++)
                            {
                                Resample(voice.mResampleData[0], SAMPLE_GRANULARITY * j,
                                         voice.mResampleData[1], SAMPLE_GRANULARITY * j,
                                         aScratch, aBufferSize * j + outofs,
                                         voice.mSrcOffset,
                                         writesamples,
                                         voice.mSamplerate,
                                         aSamplerate,
                                         step_fixed);
                            }
                        }

                        // Update counters
                        outofs += writesamples;
                        voice.mSrcOffset += writesamples * step_fixed;
                    }

                    // Handle panning and channel expansion
                    PanAndExpand(voice, aBuffer, aSamplesToRead, aBufferSize, aScratch, aChannels);

                    // clear voice if the sound is over
                    if ((voice.mFlags & AudioSourceInstance.FLAGS.LOOPING) == 0 && voice.HasEnded())
                    {
                        StopVoice_internal(mActiveVoice[i]);
                    }
                }
                else if (voice != null &&
                    (voice.mFlags & AudioSourceInstance.FLAGS.PAUSED) == 0 &&
                    (voice.mFlags & AudioSourceInstance.FLAGS.INAUDIBLE) != 0 &&
                    (voice.mFlags & AudioSourceInstance.FLAGS.INAUDIBLE_TICK) != 0)
                {
                    // Inaudible but needs ticking. Do minimal work (keep counters up to date and ask audiosource for data)
                    float step = (voice.mSamplerate / aSamplerate) * voice.mOverallRelativePlaySpeed;
                    int step_fixed = (int)Math.Floor(step * FIXPOINT_FRAC_MUL);
                    int outofs = 0;

                    if (voice.mDelaySamples > 0)
                    {
                        if (voice.mDelaySamples > aSamplesToRead)
                        {
                            outofs = aSamplesToRead;
                            voice.mDelaySamples -= aSamplesToRead;
                        }
                        else
                        {
                            outofs = voice.mDelaySamples;
                            voice.mDelaySamples = 0;
                        }
                    }

                    while (step_fixed != 0 && outofs < aSamplesToRead)
                    {
                        if (voice.mLeftoverSamples == 0)
                        {
                            // Swap resample buffers (ping-pong)
                            float[] t = voice.mResampleData[0];
                            voice.mResampleData[0] = voice.mResampleData[1];
                            voice.mResampleData[1] = t;

                            // Get a block of source data
                            int readcount = 0;
                            if (!voice.HasEnded() || (voice.mFlags & AudioSourceInstance.FLAGS.LOOPING) != 0)
                            {
                                readcount = voice.GetAudio(voice.mResampleData[0], SAMPLE_GRANULARITY, SAMPLE_GRANULARITY);
                                if (readcount < SAMPLE_GRANULARITY)
                                {
                                    if ((voice.mFlags & AudioSourceInstance.FLAGS.LOOPING) != 0)
                                    {
                                        while (readcount < SAMPLE_GRANULARITY && voice.Seek(voice.mLoopPoint, mScratch.mData, mScratchSize) == Result.NO_ERROR)
                                        {
                                            voice.mLoopCount++;
                                            int inc = voice.GetAudio(voice.mResampleData[0], SAMPLE_GRANULARITY - readcount, SAMPLE_GRANULARITY);
                                            readcount += inc;
                                            if (inc == 0) break;
                                        }
                                    }
                                }
                            }

                            // If we go past zero, crop to zero (a bit of a kludge)
                            if (voice.mSrcOffset < SAMPLE_GRANULARITY * FIXPOINT_FRAC_MUL)
                            {
                                voice.mSrcOffset = 0;
                            }
                            else
                            {
                                // We have new block of data, move pointer backwards
                                voice.mSrcOffset -= SAMPLE_GRANULARITY * FIXPOINT_FRAC_MUL;
                            }
                        }
                        else
                        {
                            voice.mLeftoverSamples = 0;
                        }

                        // Figure out how many samples we can generate from this source data.
                        int writesamples = 0;

                        if (voice.mSrcOffset < SAMPLE_GRANULARITY * FIXPOINT_FRAC_MUL)
                        {
                            writesamples = ((SAMPLE_GRANULARITY * FIXPOINT_FRAC_MUL) - voice.mSrcOffset) / step_fixed + 1;

                            // avoid reading past the current buffer..
                            if (((writesamples * step_fixed + voice.mSrcOffset) >> FIXPOINT_FRAC_BITS) >= SAMPLE_GRANULARITY)
                                writesamples--;
                        }

                        // If this is too much for our output buffer, don't write that many:
                        if (writesamples + outofs > aSamplesToRead)
                        {
                            voice.mLeftoverSamples = (writesamples + outofs) - aSamplesToRead;
                            writesamples = aSamplesToRead - outofs;
                        }

                        // Keep track of how many samples we've written so far
                        outofs += writesamples;

                        // Move source pointer onwards (writesamples may be zero)
                        voice.mSrcOffset += writesamples * step_fixed;
                    }

                    // clear voice if the sound is over
                    if ((voice.mFlags & AudioSourceInstance.FLAGS.LOOPING) == 0 && voice.HasEnded())
                    {
                        StopVoice_internal(mActiveVoice[i]);
                    }
                }
            }
        }

        private void Resample(float[] aSrc, int aSrcOffset,
            float[] aSrc1, int aSrc1Offset,
            float[] aDst, int aDstOffset,
            int aSrcPos,
            int aDstSampleCount,
            float aSrcSamplerate,
            float aDstSamplerate,
            int aStepFixed)
        {
#if MINILOUD_RESAMPLER_CATMULLROM
            ResampleCatmullrom(aSrc, aSrcOffset, aSrc1, aSrc1Offset, aDst, aDstOffset, aSrcPos, aDstSampleCount, aStepFixed);
#elif MINILOUD_RESAMPLER_LINEAR
            ResampleLinear(aSrc, aSrcOffset, aSrc1, aSrc1Offset, aDst, aDstOffset, aSrcPos, aDstSampleCount, aStepFixed);
#else
            ResamplePoint(aSrc, aSrcOffset, aSrc1, aSrc1Offset, aDst, aDstOffset, aSrcPos, aDstSampleCount, aStepFixed);
#endif
        }

        private static float CatmullRom(float t, float p0, float p1, float p2, float p3)
        {
            return 0.5f * (
                (2 * p1) +
                (-p0 + p2) * t +
                (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t +
                (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t
                );
        }

        private void ResampleCatmullrom(float[] aSrc, int aSrcOffset,
            float[] aSrc1, int aSrc1Offset,
            float[] aDst, int aDstOffset,
            int aSrcPos,
            int aDstSampleCount,
            int aStepFixed)
        {
            int pos = aSrcPos;

            for (int i = 0; i < aDstSampleCount; i++, pos += aStepFixed)
            {
                int p = pos >> FIXPOINT_FRAC_BITS;
                int f = pos & FIXPOINT_FRAC_MASK;

#if DEBUG_MINILOUD
                if (p >= SAMPLE_GRANULARITY || p < 0)
                {
                    // This should never actually happen
                    p = SAMPLE_GRANULARITY - 1;
                }
#endif

                float s0, s1, s2, s3;

                // Match exact MiniLoud Catmull-Rom history buffer indexing
                if (p == 0)
                {
                    s1 = aSrc1[aSrc1Offset + SAMPLE_GRANULARITY - 1];
                    s2 = aSrc1[aSrc1Offset + SAMPLE_GRANULARITY - 2];
                    s3 = aSrc1[aSrc1Offset + SAMPLE_GRANULARITY - 3];
                }
                else if (p == 1)
                {
                    s1 = aSrc[aSrcOffset + 0];
                    s2 = aSrc1[aSrc1Offset + SAMPLE_GRANULARITY - 1];
                    s3 = aSrc1[aSrc1Offset + SAMPLE_GRANULARITY - 2];
                }
                else if (p == 2)
                {
                    s1 = aSrc[aSrcOffset + 1];
                    s2 = aSrc[aSrcOffset + 0];
                    s3 = aSrc1[aSrc1Offset + SAMPLE_GRANULARITY - 1];
                }
                else
                {
                    s1 = aSrc[aSrcOffset + p - 1];
                    s2 = aSrc[aSrcOffset + p - 2];
                    s3 = aSrc[aSrcOffset + p - 3];
                }

                s0 = aSrc[aSrcOffset + p];

                aDst[aDstOffset + i] = CatmullRom(f / (float)FIXPOINT_FRAC_MUL, s3, s2, s1, s0);
            }
        }

        private void ResampleLinear(float[] aSrc, int aSrcOffset,
            float[] aSrc1, int aSrc1Offset,
            float[] aDst, int aDstOffset,
            int aSrcPos,
            int aDstSampleCount,
            int aStepFixed)
        {
            int pos = aSrcPos;

            for (int i = 0; i < aDstSampleCount; i++, pos += aStepFixed)
            {
                int p = pos >> FIXPOINT_FRAC_BITS;
                int f = pos & FIXPOINT_FRAC_MASK;

#if DEBUG_MINILOUD
                if (p >= SAMPLE_GRANULARITY || p < 0)
                {
                    // This should never actually happen
                    p = SAMPLE_GRANULARITY - 1;
                }
#endif

                float s1 = aSrc1[aSrc1Offset + SAMPLE_GRANULARITY - 1];
                float s2 = aSrc[aSrcOffset + p];
                if (p != 0)
                {
                    s1 = aSrc[aSrcOffset + p - 1];
                }
                aDst[aDstOffset + i] = s1 + (s2 - s1) * f * (1.0f / FIXPOINT_FRAC_MUL);
            }
        }

        private void ResamplePoint(float[] aSrc, int aSrcOffset,
            float[] aSrc1, int aSrc1Offset,
            float[] aDst, int aDstOffset,
            int aSrcPos,
            int aDstSampleCount,
            int aStepFixed)
        {
            int pos = aSrcPos;

            for (int i = 0; i < aDstSampleCount; i++, pos += aStepFixed)
            {
                int p = pos >> FIXPOINT_FRAC_BITS;
                aDst[aDstOffset + i] = aSrc[aSrcOffset + p];
            }
        }

        private void PanAndExpand(AudioSourceInstance aVoice, float[] aBuffer, int aSamplesToRead, int aBufferSize, float[] aScratch, int aChannels)
        {
            float[] pan = mPanBuffer; // current speaker volume
            float[] pand = mPanDestBuffer; // destination speaker volume
            float[] pani = mPanIncrementBuffer; // speaker volume increment per sample

            for (int k = 0; k < aChannels; k++)
            {
                pan[k] = aVoice.mCurrentChannelVolume[k];
                pand[k] = aVoice.mChannelVolume[k] * aVoice.mOverallVolume;
                pani[k] = (pand[k] - pan[k]) / aSamplesToRead;
            }

            int ofs = 0;
            switch (aChannels)
            {
                case 1: // Target is mono. Sum everything.
                    for (int j = 0; j < aVoice.mChannels; j++, ofs += aBufferSize)
                    {
                        pan[0] = aVoice.mCurrentChannelVolume[0];
                        for (int k = 0; k < aSamplesToRead; k++)
                        {
                            pan[0] += pani[0];
                            aBuffer[k] += aScratch[ofs + k] * pan[0];
                        }
                    }
                    break;
                case 2:
                    switch (aVoice.mChannels)
                    {
                        case 2: // 2->2
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                aBuffer[j + 0] += s1 * pan[0];
                                aBuffer[j + aBufferSize] += s2 * pan[1];
                            }
                            break;
                        case 1: // 1->2
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                float s = aScratch[j];
                                aBuffer[j + 0] += s * pan[0];
                                aBuffer[j + aBufferSize] += s * pan[1];
                            }
                            break;
                        case 4: // 4->2, just sum lefties and righties
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                float s3 = aScratch[aBufferSize * 2 + j];
                                float s4 = aScratch[aBufferSize * 3 + j];
                                aBuffer[j + 0] += 0.5f * (s1 + s3) * pan[0];
                                aBuffer[j + aBufferSize] += 0.5f * (s2 + s4) * pan[1];
                            }
                            break;
                        case 6: // 6->2, just sum lefties and righties, add a bit of center and sub
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                float s3 = aScratch[aBufferSize * 2 + j];
                                float s4 = aScratch[aBufferSize * 3 + j];
                                float s5 = aScratch[aBufferSize * 4 + j];
                                float s6 = aScratch[aBufferSize * 5 + j];
                                aBuffer[j + 0] += 0.3f * (s1 + s3 + s4 + s5) * pan[0];
                                aBuffer[j + aBufferSize] += 0.3f * (s2 + s3 + s4 + s6) * pan[1];
                            }
                            break;
                        case 8: // 8->2, just sum lefties and righties, add a bit of center and sub
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                float s3 = aScratch[aBufferSize * 2 + j];
                                float s4 = aScratch[aBufferSize * 3 + j];
                                float s5 = aScratch[aBufferSize * 4 + j];
                                float s6 = aScratch[aBufferSize * 5 + j];
                                float s7 = aScratch[aBufferSize * 6 + j];
                                float s8 = aScratch[aBufferSize * 7 + j];
                                aBuffer[j + 0] += 0.2f * (s1 + s3 + s4 + s5 + s7) * pan[0];
                                aBuffer[j + aBufferSize] += 0.2f * (s2 + s3 + s4 + s6 + s8) * pan[1];
                            }
                            break;
                    }
                    break;
                case 4:
                    switch (aVoice.mChannels)
                    {
                        case 4: // 4->4
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                float s3 = aScratch[aBufferSize * 2 + j];
                                float s4 = aScratch[aBufferSize * 3 + j];
                                aBuffer[j + 0] += s1 * pan[0];
                                aBuffer[j + aBufferSize] += s2 * pan[1];
                                aBuffer[j + aBufferSize * 2] += s3 * pan[2];
                                aBuffer[j + aBufferSize * 3] += s4 * pan[3];
                            }
                            break;
                        case 2: // 2->4
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                aBuffer[j + 0] += s1 * pan[0];
                                aBuffer[j + aBufferSize] += s2 * pan[1];
                                aBuffer[j + aBufferSize * 2] += s1 * pan[2];
                                aBuffer[j + aBufferSize * 3] += s2 * pan[3];
                            }
                            break;
                        case 1: // 1->4
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                float s = aScratch[j];
                                aBuffer[j + 0] += s * pan[0];
                                aBuffer[j + aBufferSize] += s * pan[1];
                                aBuffer[j + aBufferSize * 2] += s * pan[2];
                                aBuffer[j + aBufferSize * 3] += s * pan[3];
                            }
                            break;
                        case 6: // 6->4
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                float s3 = aScratch[aBufferSize * 2 + j];
                                float s4 = aScratch[aBufferSize * 3 + j];
                                float s5 = aScratch[aBufferSize * 4 + j];
                                float s6 = aScratch[aBufferSize * 5 + j];
                                float c = (s3 + s4) * 0.7f;
                                aBuffer[j + 0] += s1 * pan[0] + c;
                                aBuffer[j + aBufferSize] += s2 * pan[1] + c;
                                aBuffer[j + aBufferSize * 2] += s5 * pan[2];
                                aBuffer[j + aBufferSize * 3] += s6 * pan[3];
                            }
                            break;
                        case 8: // 8->4
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                float s3 = aScratch[aBufferSize * 2 + j];
                                float s4 = aScratch[aBufferSize * 3 + j];
                                float s5 = aScratch[aBufferSize * 4 + j];
                                float s6 = aScratch[aBufferSize * 5 + j];
                                float s7 = aScratch[aBufferSize * 6 + j];
                                float s8 = aScratch[aBufferSize * 7 + j];
                                float c = (s3 + s4) * 0.7f;
                                aBuffer[j + 0] += s1 * pan[0] + c;
                                aBuffer[j + aBufferSize] += s2 * pan[1] + c;
                                aBuffer[j + aBufferSize * 2] += 0.5f * (s5 + s7) * pan[2];
                                aBuffer[j + aBufferSize * 3] += 0.5f * (s6 + s8) * pan[3];
                            }
                            break;
                    }
                    break;
                case 6:
                    switch (aVoice.mChannels)
                    {
                        case 6: // 6->6
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                pan[4] += pani[4];
                                pan[5] += pani[5];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                float s3 = aScratch[aBufferSize * 2 + j];
                                float s4 = aScratch[aBufferSize * 3 + j];
                                float s5 = aScratch[aBufferSize * 4 + j];
                                float s6 = aScratch[aBufferSize * 5 + j];
                                aBuffer[j + 0] += s1 * pan[0];
                                aBuffer[j + aBufferSize] += s2 * pan[1];
                                aBuffer[j + aBufferSize * 2] += s3 * pan[2];
                                aBuffer[j + aBufferSize * 3] += s4 * pan[3];
                                aBuffer[j + aBufferSize * 4] += s5 * pan[4];
                                aBuffer[j + aBufferSize * 5] += s6 * pan[5];
                            }
                            break;
                        case 4: // 4->6
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                pan[4] += pani[4];
                                pan[5] += pani[5];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                float s3 = aScratch[aBufferSize * 2 + j];
                                float s4 = aScratch[aBufferSize * 3 + j];
                                aBuffer[j + 0] += s1 * pan[0];
                                aBuffer[j + aBufferSize] += s2 * pan[1];
                                aBuffer[j + aBufferSize * 2] += 0.5f * (s1 + s2) * pan[2];
                                aBuffer[j + aBufferSize * 3] += 0.25f * (s1 + s2 + s3 + s4) * pan[3];
                                aBuffer[j + aBufferSize * 4] += s3 * pan[4];
                                aBuffer[j + aBufferSize * 5] += s4 * pan[5];
                            }
                            break;
                        case 2: // 2->6
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                pan[4] += pani[4];
                                pan[5] += pani[5];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                aBuffer[j + 0] += s1 * pan[0];
                                aBuffer[j + aBufferSize] += s2 * pan[1];
                                aBuffer[j + aBufferSize * 2] += 0.5f * (s1 + s2) * pan[2];
                                aBuffer[j + aBufferSize * 3] += 0.5f * (s1 + s2) * pan[3];
                                aBuffer[j + aBufferSize * 4] += s1 * pan[4];
                                aBuffer[j + aBufferSize * 5] += s2 * pan[5];
                            }
                            break;
                        case 1: // 1->6
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                pan[4] += pani[4];
                                pan[5] += pani[5];
                                float s = aScratch[j];
                                aBuffer[j + 0] += s * pan[0];
                                aBuffer[j + aBufferSize] += s * pan[1];
                                aBuffer[j + aBufferSize * 2] += s * pan[2];
                                aBuffer[j + aBufferSize * 3] += s * pan[3];
                                aBuffer[j + aBufferSize * 4] += s * pan[4];
                                aBuffer[j + aBufferSize * 5] += s * pan[5];
                            }
                            break;
                        case 8: // 8->6
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                pan[4] += pani[4];
                                pan[5] += pani[5];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                float s3 = aScratch[aBufferSize * 2 + j];
                                float s4 = aScratch[aBufferSize * 3 + j];
                                float s5 = aScratch[aBufferSize * 4 + j];
                                float s6 = aScratch[aBufferSize * 5 + j];
                                float s7 = aScratch[aBufferSize * 6 + j];
                                float s8 = aScratch[aBufferSize * 7 + j];
                                aBuffer[j + 0] += s1 * pan[0];
                                aBuffer[j + aBufferSize] += s2 * pan[1];
                                aBuffer[j + aBufferSize * 2] += s3 * pan[2];
                                aBuffer[j + aBufferSize * 3] += s4 * pan[3];
                                aBuffer[j + aBufferSize * 4] += 0.5f * (s5 + s7) * pan[4];
                                aBuffer[j + aBufferSize * 5] += 0.5f * (s6 + s8) * pan[5];
                            }
                            break;
                    }
                    break;
                case 8:
                    switch (aVoice.mChannels)
                    {
                        case 8: // 8->8
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                pan[4] += pani[4];
                                pan[5] += pani[5];
                                pan[6] += pani[6];
                                pan[7] += pani[7];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                float s3 = aScratch[aBufferSize * 2 + j];
                                float s4 = aScratch[aBufferSize * 3 + j];
                                float s5 = aScratch[aBufferSize * 4 + j];
                                float s6 = aScratch[aBufferSize * 5 + j];
                                float s7 = aScratch[aBufferSize * 6 + j];
                                float s8 = aScratch[aBufferSize * 7 + j];
                                aBuffer[j + 0] += s1 * pan[0];
                                aBuffer[j + aBufferSize] += s2 * pan[1];
                                aBuffer[j + aBufferSize * 2] += s3 * pan[2];
                                aBuffer[j + aBufferSize * 3] += s4 * pan[3];
                                aBuffer[j + aBufferSize * 4] += s5 * pan[4];
                                aBuffer[j + aBufferSize * 5] += s6 * pan[5];
                                aBuffer[j + aBufferSize * 6] += s7 * pan[6];
                                aBuffer[j + aBufferSize * 7] += s8 * pan[7];
                            }
                            break;
                        case 6: // 6->8
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                pan[4] += pani[4];
                                pan[5] += pani[5];
                                pan[6] += pani[6];
                                pan[7] += pani[7];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                float s3 = aScratch[aBufferSize * 2 + j];
                                float s4 = aScratch[aBufferSize * 3 + j];
                                float s5 = aScratch[aBufferSize * 4 + j];
                                float s6 = aScratch[aBufferSize * 5 + j];
                                aBuffer[j + 0] += s1 * pan[0];
                                aBuffer[j + aBufferSize] += s2 * pan[1];
                                aBuffer[j + aBufferSize * 2] += s3 * pan[2];
                                aBuffer[j + aBufferSize * 3] += s4 * pan[3];
                                aBuffer[j + aBufferSize * 4] += 0.5f * (s5 + s1) * pan[4];
                                aBuffer[j + aBufferSize * 5] += 0.5f * (s6 + s2) * pan[5];
                                aBuffer[j + aBufferSize * 6] += s5 * pan[6];
                                aBuffer[j + aBufferSize * 7] += s6 * pan[7];
                            }
                            break;
                        case 4: // 4->8
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                pan[4] += pani[4];
                                pan[5] += pani[5];
                                pan[6] += pani[6];
                                pan[7] += pani[7];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                float s3 = aScratch[aBufferSize * 2 + j];
                                float s4 = aScratch[aBufferSize * 3 + j];
                                aBuffer[j + 0] += s1 * pan[0];
                                aBuffer[j + aBufferSize] += s2 * pan[1];
                                aBuffer[j + aBufferSize * 2] += 0.5f * (s1 + s2) * pan[2];
                                aBuffer[j + aBufferSize * 3] += 0.25f * (s1 + s2 + s3 + s4) * pan[3];
                                aBuffer[j + aBufferSize * 4] += 0.5f * (s1 + s3) * pan[4];
                                aBuffer[j + aBufferSize * 5] += 0.5f * (s2 + s4) * pan[5];
                                aBuffer[j + aBufferSize * 6] += s3 * pan[6];
                                aBuffer[j + aBufferSize * 7] += s4 * pan[7];
                            }
                            break;
                        case 2: // 2->8
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                pan[4] += pani[4];
                                pan[5] += pani[5];
                                pan[6] += pani[6];
                                pan[7] += pani[7];
                                float s1 = aScratch[j];
                                float s2 = aScratch[aBufferSize + j];
                                aBuffer[j + 0] += s1 * pan[0];
                                aBuffer[j + aBufferSize] += s2 * pan[1];
                                aBuffer[j + aBufferSize * 2] += 0.5f * (s1 + s2) * pan[2];
                                aBuffer[j + aBufferSize * 3] += 0.5f * (s1 + s2) * pan[3];
                                aBuffer[j + aBufferSize * 4] += s1 * pan[4];
                                aBuffer[j + aBufferSize * 5] += s2 * pan[5];
                                aBuffer[j + aBufferSize * 6] += s1 * pan[6];
                                aBuffer[j + aBufferSize * 7] += s2 * pan[7];
                            }
                            break;
                        case 1: // 1->8
                            for (int j = 0; j < aSamplesToRead; j++)
                            {
                                pan[0] += pani[0];
                                pan[1] += pani[1];
                                pan[2] += pani[2];
                                pan[3] += pani[3];
                                pan[4] += pani[4];
                                pan[5] += pani[5];
                                pan[6] += pani[6];
                                pan[7] += pani[7];
                                float s = aScratch[j];
                                aBuffer[j + 0] += s * pan[0];
                                aBuffer[j + aBufferSize] += s * pan[1];
                                aBuffer[j + aBufferSize * 2] += s * pan[2];
                                aBuffer[j + aBufferSize * 3] += s * pan[3];
                                aBuffer[j + aBufferSize * 4] += s * pan[4];
                                aBuffer[j + aBufferSize * 5] += s * pan[5];
                                aBuffer[j + aBufferSize * 6] += s * pan[6];
                                aBuffer[j + aBufferSize * 7] += s * pan[7];
                            }
                            break;
                    }
                    break;
            }

            for (int k = 0; k < aChannels; k++)
                aVoice.mCurrentChannelVolume[k] = pand[k];
        }

        private void CalcActiveVoices_internal()
        {
            mActiveVoiceDirty = false;

            // Populate active voices
            int candidates = 0;
            int mustlive = 0;
            for (int i = 0; i < mHighestVoice; i++)
            {
                if (mVoice[i] != null && ((mVoice[i].mFlags & (AudioSourceInstance.FLAGS.INAUDIBLE | AudioSourceInstance.FLAGS.PAUSED)) == 0 || (mVoice[i].mFlags & AudioSourceInstance.FLAGS.INAUDIBLE_TICK) != 0))
                {
                    mActiveVoice[candidates] = i;
                    candidates++;
                    if ((mVoice[i].mFlags & AudioSourceInstance.FLAGS.INAUDIBLE_TICK) != 0)
                    {
                        mActiveVoice[candidates - 1] = mActiveVoice[mustlive];
                        mActiveVoice[mustlive] = i;
                        mustlive++;
                    }
                }
            }

            // Check for early out
            if (candidates <= mMaxActiveVoices)
            {
                mActiveVoiceCount = candidates;
                MapResampleBuffers_internal();
                return;
            }

            mActiveVoiceCount = mMaxActiveVoices;

            if (mustlive >= mMaxActiveVoices)
            {
                // Oopsie. Well, nothing to sort, since the "must live" voices already
                // ate all our active voice slots.
                return;
            }

            // If we get this far, there's nothing to it: we'll have to sort the voices to find the most audible.
            // Implement the exact MiniLoud iterative partial quicksort
            int left = 0;
            int[] stack = mQuicksortStack;
            int pos = 0;
            int right;
            int len = candidates - mustlive;
            int k = mActiveVoiceCount;

            for (; ; )
            {
                for (; left + 1 < len; len++)
                {
                    if (pos == 24) len = stack[pos = 0];
                    int pivot = mActiveVoice[mustlive + left];
                    float pivotvol = mVoice[pivot].mOverallVolume;
                    stack[pos++] = len;
                    for (right = left - 1; ;)
                    {
                        do
                        {
                            right++;
                        }
                        while (mVoice[mActiveVoice[mustlive + right]].mOverallVolume > pivotvol);
                        do
                        {
                            len--;
                        }
                        while (pivotvol > mVoice[mActiveVoice[mustlive + len]].mOverallVolume);
                        if (right >= len) break;
                        int temp = mActiveVoice[mustlive + right];
                        mActiveVoice[mustlive + right] = mActiveVoice[mustlive + len];
                        mActiveVoice[mustlive + len] = temp;
                    }
                }
                if (pos == 0) break;
                if (left >= k) break;
                left = len;
                len = stack[--pos];
            }

            MapResampleBuffers_internal();
        }

        private void MapResampleBuffers_internal()
        {
            // Match MiniLoud's exact logic
            byte[] live = mLiveChannelBuffer; // Using bytes to match C++ char array
            Array.Clear(live, 0, mMaxActiveVoices);

            for (int i = 0; i < mMaxActiveVoices; i++)
            {
                for (int j = 0; j < mMaxActiveVoices; j++)
                {
                    if (mResampleDataOwner[i] != null && mResampleDataOwner[i] == mVoice[mActiveVoice[j]])
                    {
                        live[i] |= 1; // Live channel
                        live[j] |= 2; // Live voice
                    }
                }
            }

            for (int i = 0; i < mMaxActiveVoices; i++)
            {
                if ((live[i] & 1) == 0 && mResampleDataOwner[i] != null) // For all dead channels with owners..
                {
                    mResampleDataOwner[i].mResampleData[0] = null;
                    mResampleDataOwner[i].mResampleData[1] = null;
                    mResampleDataOwner[i] = null;
                }
            }

            int latestfree = 0;
            for (int i = 0; i < mActiveVoiceCount; i++)
            {
                if ((live[i] & 2) == 0 && mVoice[mActiveVoice[i]] != null) // For all live voices with no channel..
                {
                    int found = -1;
                    for (int j = latestfree; found == -1 && j < mMaxActiveVoices; j++)
                    {
                        if (mResampleDataOwner[j] == null)
                        {
                            found = j;
                        }
                    }
                    // MINILOUD_ASSERT(found != -1);
                    if (found != -1)
                    {
                        mResampleDataOwner[found] = mVoice[mActiveVoice[i]];
                        mResampleDataOwner[found].mResampleData[0] = mResampleData[found * 2 + 0].mData;
                        mResampleDataOwner[found].mResampleData[1] = mResampleData[found * 2 + 1].mData;
                        Array.Clear(mResampleDataOwner[found].mResampleData[0], 0, mResampleDataOwner[found].mResampleData[0].Length);
                        Array.Clear(mResampleDataOwner[found].mResampleData[1], 0, mResampleDataOwner[found].mResampleData[1].Length);
                        latestfree = found + 1;
                    }
                }
            }
        }

        private void Clip_internal(AlignedFloatBuffer aBuffer, AlignedFloatBuffer aDestBuffer, int aSamples, float aVolume0, float aVolume1)
        {
            float vd = (aVolume1 - aVolume0) / aSamples;
            float v = aVolume0;
            int samplequads = (aSamples + 3) / 4; // rounded up

            // Clip
            if ((mFlags & MiniloudFlags.CLIP_ROUNDOFF) != 0)
            {
                int c = 0;
                int d = 0;
                for (int j = 0; j < mChannels; j++)
                {
                    v = aVolume0;
                    for (int i = 0; i < samplequads; i++)
                    {
                        float f1 = aBuffer.mData[c] * v; c++; v += vd;
                        float f2 = aBuffer.mData[c] * v; c++; v += vd;
                        float f3 = aBuffer.mData[c] * v; c++; v += vd;
                        float f4 = aBuffer.mData[c] * v; c++; v += vd;

                        f1 = (f1 <= -1.65f) ? -0.9862875f : (f1 >= 1.65f) ? 0.9862875f : (0.87f * f1 - 0.1f * f1 * f1 * f1);
                        f2 = (f2 <= -1.65f) ? -0.9862875f : (f2 >= 1.65f) ? 0.9862875f : (0.87f * f2 - 0.1f * f2 * f2 * f2);
                        f3 = (f3 <= -1.65f) ? -0.9862875f : (f3 >= 1.65f) ? 0.9862875f : (0.87f * f3 - 0.1f * f3 * f3 * f3);
                        f4 = (f4 <= -1.65f) ? -0.9862875f : (f4 >= 1.65f) ? 0.9862875f : (0.87f * f4 - 0.1f * f4 * f4 * f4);

                        aDestBuffer.mData[d] = f1 * mPostClipScaler; d++;
                        aDestBuffer.mData[d] = f2 * mPostClipScaler; d++;
                        aDestBuffer.mData[d] = f3 * mPostClipScaler; d++;
                        aDestBuffer.mData[d] = f4 * mPostClipScaler; d++;
                    }
                }
            }
            else
            {
                int c = 0;
                int d = 0;
                for (int j = 0; j < mChannels; j++)
                {
                    v = aVolume0;
                    for (int i = 0; i < samplequads; i++)
                    {
                        float f1 = aBuffer.mData[c] * v; c++; v += vd;
                        float f2 = aBuffer.mData[c] * v; c++; v += vd;
                        float f3 = aBuffer.mData[c] * v; c++; v += vd;
                        float f4 = aBuffer.mData[c] * v; c++; v += vd;

                        f1 = (f1 <= -1) ? -1 : (f1 >= 1) ? 1 : f1;
                        f2 = (f2 <= -1) ? -1 : (f2 >= 1) ? 1 : f2;
                        f3 = (f3 <= -1) ? -1 : (f3 >= 1) ? 1 : f3;
                        f4 = (f4 <= -1) ? -1 : (f4 >= 1) ? 1 : f4;

                        aDestBuffer.mData[d] = f1 * mPostClipScaler; d++;
                        aDestBuffer.mData[d] = f2 * mPostClipScaler; d++;
                        aDestBuffer.mData[d] = f3 * mPostClipScaler; d++;
                        aDestBuffer.mData[d] = f4 * mPostClipScaler; d++;
                    }
                }
            }
        }

        public float[] GetWave()
        {
            lock (mAudioMutex)
            {
                for (int i = 0; i < 256; i++)
                    mWaveData[i] = mVisualizationWaveData[i];
            }
            return mWaveData;
        }

        public float GetApproximateVolume(int aChannel)
        {
            if (aChannel > mChannels)
                return 0;
            float vol = 0;
            lock (mAudioMutex)
            {
                vol = mVisualizationChannelVolume[aChannel];
            }
            return vol;
        }

        public float[] CalcFFT()
        {
            lock (mAudioMutex)
            {
                float[] temp = new float[1024];
                for (int i = 0; i < 256; i++)
                {
                    temp[i * 2] = mVisualizationWaveData[i];
                    temp[i * 2 + 1] = 0;
                    temp[i + 512] = 0;
                    temp[i + 768] = 0;
                }
                // Would need FFT implementation here
                // MiniLoud::FFT::fft1024(temp);
                for (int i = 0; i < 256; i++)
                {
                    float real = temp[i * 2];
                    float imag = temp[i * 2 + 1];
                    mFFTData[i] = (float)Math.Sqrt(real * real + imag * imag);
                }
            }
            return mFFTData;
        }
    }

    public class AudioMixer
    {
        private Miniloud mMiniloud;
        private float[] mTempBuffer;
        private Dictionary<int, int> mHandleToVoice;
        private int mNextHandle;

        public AudioMixer(int sampleRate = 44100, int channels = 2)
        {
            mMiniloud = new Miniloud();
            mMiniloud.Init(sampleRate, 2048, channels, 16, MiniloudFlags.CLIP_ROUNDOFF);
            mHandleToVoice = new Dictionary<int, int>();
            mNextHandle = 1;
        }

        public int Play(float[] audioData, int channels, float sampleRate, float volume = 1.0f, float pan = 0.0f, float pitch = 1.0f, float position = 0.0f, bool loop = false)
        {
            var audioSource = new AudioSourceInstance();
            audioSource.SetAudioData(audioData, channels, sampleRate);

            if (loop)
                audioSource.mFlags |= AudioSourceInstance.FLAGS.LOOPING;

            int voiceHandle = mMiniloud.Play(audioSource, volume, pan, pitch, position, false);
            if (voiceHandle >= 0)
            {
                int handle = mNextHandle++;
                mHandleToVoice[handle] = voiceHandle;
                return handle;
            }
            return -1;
        }

        public void ProcessAudio(float[] data, int channels)
        {
            int samples = data.Length / channels;
            mMiniloud.Mix(data, samples);
        }

        public void SetVolume(int handle, float volume)
        {
            if (mHandleToVoice.TryGetValue(handle, out int voiceHandle))
                mMiniloud.SetVoiceVolume(voiceHandle, volume);
        }

        public void SetPan(int handle, float pan)
        {
            if (mHandleToVoice.TryGetValue(handle, out int voiceHandle))
                mMiniloud.SetVoicePan(voiceHandle, pan);
        }

        public void SetPitch(int handle, float pitch)
        {
            if (mHandleToVoice.TryGetValue(handle, out int voiceHandle))
                mMiniloud.SetVoiceRelativePlaySpeed(voiceHandle, pitch);
        }

        public void SetPosition(int handle, double position)
        {
            if (mHandleToVoice.TryGetValue(handle, out int voiceHandle))
                mMiniloud.SetVoicePosition(voiceHandle, position);
        }

        public void Pause(int handle)
        {
            if (mHandleToVoice.TryGetValue(handle, out int voiceHandle))
                mMiniloud.SetVoicePause(voiceHandle, true);
        }

        public void Resume(int handle)
        {
            if (mHandleToVoice.TryGetValue(handle, out int voiceHandle))
                mMiniloud.SetVoicePause(voiceHandle, false);
        }

        public void Stop(int handle)
        {
            if (mHandleToVoice.TryGetValue(handle, out int voiceHandle))
            {
                mMiniloud.StopVoice(voiceHandle);
                mHandleToVoice.Remove(handle);
            }
        }

        public float GetVolume(int handle)
        {
            if (mHandleToVoice.TryGetValue(handle, out int voiceHandle))
                return mMiniloud.GetVoiceVolume(voiceHandle);
            return 0.0f;
        }

        public float GetPan(int handle)
        {
            if (mHandleToVoice.TryGetValue(handle, out int voiceHandle))
                return mMiniloud.GetVoicePan(voiceHandle);
            return 0.0f;
        }

        public float GetPitch(int handle)
        {
            if (mHandleToVoice.TryGetValue(handle, out int voiceHandle))
                return mMiniloud.GetVoiceRelativePlaySpeed(voiceHandle);
            return 1.0f;
        }

        public double GetPosition(int handle)
        {
            if (mHandleToVoice.TryGetValue(handle, out int voiceHandle))
                return mMiniloud.GetVoicePosition(voiceHandle);
            return 0.0;
        }
    }

    // API Interface Types
    public class AudioResource
    {
        public float[] audioData;
        public int channels;
        public float sampleRate;
        public float duration;
    }

    public class AudioHandle
    {
        public int internalHandle;
        public bool isValid;

        public AudioHandle(int handle)
        {
            internalHandle = handle;
            isValid = handle >= 0;
        }
    }

    // Command Queue Implementation
    public enum CommandType
    {
        Play,
        Stop,
        Pause,
        Resume,
        SetVolume,
        SetPan,
        SetPitch,
        SetPosition,
        StopAll
    }

    public struct AudioCommand
    {
        public CommandType Type;
        public int Handle;
        public float FloatParam1;
        public float FloatParam2;
        public float FloatParam3;
        public float FloatParam4;
        public bool BoolParam1;
        public int IntParam1;
        public AudioSourceInstance AudioSource; // For Play command
    }

    // Lock-free circular buffer for commands
    public class CommandQueue
    {
        private readonly AudioCommand[] commands;
        private readonly int capacity;
        private volatile int writeIndex;
        private volatile int readIndex;
        private readonly object writeLock = new object();

        public CommandQueue(int capacity = 256)
        {
            this.capacity = capacity;
            this.commands = new AudioCommand[capacity];
            this.writeIndex = 0;
            this.readIndex = 0;
        }

        public bool TryEnqueue(ref AudioCommand command)
        {
            lock (writeLock)
            {
                int nextWrite = (writeIndex + 1) % capacity;
                if (nextWrite == readIndex) // Queue full
                    return false;

                commands[writeIndex] = command;
                writeIndex = nextWrite;
                return true;
            }
        }

        public bool TryDequeue(out AudioCommand command)
        {
            if (readIndex == writeIndex) // Queue empty
            {
                command = default;
                return false;
            }

            command = commands[readIndex];
            readIndex = (readIndex + 1) % capacity;
            return true;
        }

        public void Clear()
        {
            readIndex = writeIndex;
        }
    }

    public class MiniLoudAudio
    {
        private AudioMixer mixer;
        private Dictionary<int, VoiceState> voiceStates;
        private CommandQueue commandQueue;
        private int nextHandle = 1;
        private readonly object stateLock = new object();

        private class VoiceState
        {
            // Audio thread data
            public AudioSourceInstance audioSource;
            public int voiceHandle;

            // Shadow values (main thread visible)
            public float volume = 1.0f;
            public float pan = 0.0f;
            public float pitch = 1.0f;
            public double position = 0.0;
            public bool isPlaying = true;
            public bool isPaused = false;
        }

        public MiniLoudAudio(int sampleRate = 44100, int channels = 2)
        {
            mixer = new AudioMixer(sampleRate, channels);
            voiceStates = new Dictionary<int, VoiceState>();
            commandQueue = new CommandQueue(256);
        }

        public float GetDuration(AudioResource audio)
        {
            if (audio?.audioData == null) return 0.0f;
            return audio.duration;
        }

        public void Destroy(AudioResource audio)
        {
            // No cleanup needed in this implementation
        }

        public AudioHandle Mute(AudioResource audio)
        {
            return Play(audio, 0.0f, 0.0f, 1.0f, 0.0f, false);
        }

        public AudioHandle Play(AudioResource audio, float volume = 0.5f, float pan = 0.0f, float pitch = 1.0f, float position = 0.0f, bool loop = false)
        {
            if (audio?.audioData == null)
                return new AudioHandle(-1);

            int handle;
            lock (stateLock)
            {
                handle = nextHandle++;

                // Create voice state with shadow values immediately
                voiceStates[handle] = new VoiceState
                {
                    volume = volume,
                    pan = pan,
                    pitch = pitch,
                    position = position,
                    isPlaying = true,
                    isPaused = false
                };
            }

            // Create audio source instance
            var audioSource = new AudioSourceInstance();
            audioSource.SetAudioData(audio.audioData, audio.channels, audio.sampleRate);
            if (loop)
                audioSource.mFlags |= AudioSourceInstance.FLAGS.LOOPING;

            // Enqueue play command
            var command = new AudioCommand
            {
                Type = CommandType.Play,
                Handle = handle,
                FloatParam1 = volume,
                FloatParam2 = pan,
                FloatParam3 = pitch,
                FloatParam4 = position,
                BoolParam1 = loop,
                AudioSource = audioSource
            };

            if (!commandQueue.TryEnqueue(ref command))
            {
                // Queue full, handle error
                lock (stateLock)
                {
                    voiceStates.Remove(handle);
                }
                return new AudioHandle(-1);
            }

            return new AudioHandle(handle);
        }

        public void Pause(AudioHandle handle)
        {
            if (handle?.isValid != true) return;

            lock (stateLock)
            {
                if (voiceStates.TryGetValue(handle.internalHandle, out var state))
                {
                    state.isPaused = true;
                }
            }

            var command = new AudioCommand
            {
                Type = CommandType.Pause,
                Handle = handle.internalHandle
            };
            commandQueue.TryEnqueue(ref command);
        }

        public void Resume(AudioHandle handle)
        {
            if (handle?.isValid != true) return;

            lock (stateLock)
            {
                if (voiceStates.TryGetValue(handle.internalHandle, out var state))
                {
                    state.isPaused = false;
                }
            }

            var command = new AudioCommand
            {
                Type = CommandType.Resume,
                Handle = handle.internalHandle
            };
            commandQueue.TryEnqueue(ref command);
        }

        public void Stop(AudioHandle handle)
        {
            if (handle?.isValid != true) return;

            lock (stateLock)
            {
                if (voiceStates.TryGetValue(handle.internalHandle, out var state))
                {
                    state.isPlaying = false;
                }
            }

            var command = new AudioCommand
            {
                Type = CommandType.Stop,
                Handle = handle.internalHandle
            };
            commandQueue.TryEnqueue(ref command);
            handle.isValid = false;
        }

        public float GetVolume(AudioHandle handle)
        {
            if (handle?.isValid != true) return 0.0f;

            lock (stateLock)
            {
                if (voiceStates.TryGetValue(handle.internalHandle, out var state))
                {
                    return state.volume;
                }
            }
            return 0.0f;
        }

        public void SetVolume(AudioHandle handle, float volume)
        {
            if (handle?.isValid != true) return;

            lock (stateLock)
            {
                if (voiceStates.TryGetValue(handle.internalHandle, out var state))
                {
                    state.volume = volume;
                }
            }

            var command = new AudioCommand
            {
                Type = CommandType.SetVolume,
                Handle = handle.internalHandle,
                FloatParam1 = volume
            };
            commandQueue.TryEnqueue(ref command);
        }

        public float GetPan(AudioHandle handle)
        {
            if (handle?.isValid != true) return 0.0f;

            lock (stateLock)
            {
                if (voiceStates.TryGetValue(handle.internalHandle, out var state))
                {
                    return state.pan;
                }
            }
            return 0.0f;
        }

        public void SetPan(AudioHandle handle, float pan)
        {
            if (handle?.isValid != true) return;

            lock (stateLock)
            {
                if (voiceStates.TryGetValue(handle.internalHandle, out var state))
                {
                    state.pan = pan;
                }
            }

            var command = new AudioCommand
            {
                Type = CommandType.SetPan,
                Handle = handle.internalHandle,
                FloatParam1 = pan
            };
            commandQueue.TryEnqueue(ref command);
        }

        public float GetPitch(AudioHandle handle)
        {
            if (handle?.isValid != true) return 1.0f;

            lock (stateLock)
            {
                if (voiceStates.TryGetValue(handle.internalHandle, out var state))
                {
                    return state.pitch;
                }
            }
            return 1.0f;
        }

        public void SetPitch(AudioHandle handle, float pitch)
        {
            if (handle?.isValid != true) return;

            lock (stateLock)
            {
                if (voiceStates.TryGetValue(handle.internalHandle, out var state))
                {
                    state.pitch = pitch;
                }
            }

            var command = new AudioCommand
            {
                Type = CommandType.SetPitch,
                Handle = handle.internalHandle,
                FloatParam1 = pitch
            };
            commandQueue.TryEnqueue(ref command);
        }

        public float GetPosition(AudioHandle handle)
        {
            if (handle?.isValid != true) return 0.0f;

            lock (stateLock)
            {
                if (voiceStates.TryGetValue(handle.internalHandle, out var state))
                {
                    return (float)state.position;
                }
            }
            return 0.0f;
        }

        public void SetPosition(AudioHandle handle, float position)
        {
            if (handle?.isValid != true) return;

            lock (stateLock)
            {
                if (voiceStates.TryGetValue(handle.internalHandle, out var state))
                {
                    state.position = position;
                }
            }

            var command = new AudioCommand
            {
                Type = CommandType.SetPosition,
                Handle = handle.internalHandle,
                FloatParam1 = position
            };
            commandQueue.TryEnqueue(ref command);
        }

        /// <summary>
        /// This should be called from so called "audio thread"
        /// </summary>
        public void ProcessAudio(float[] data, int channels)
        {
            // Process commands before mixing
            ProcessCommandQueue();

            // Mix audio
            mixer.ProcessAudio(data, channels);

            // Process command queue again (in case some commands were scheduled during mixing)
            ProcessCommandQueue();

            // Update shadow positions after mixing and flushing commands
            UpdateShadowPositions();
        }

        private void ProcessCommandQueue()
        {
            while (commandQueue.TryDequeue(out AudioCommand command))
            {
                switch (command.Type)
                {
                    case CommandType.Play:
                        {
                            int voiceHandle = mixer.Play(
                                command.AudioSource.mAudioData,
                                command.AudioSource.mChannels,
                                command.AudioSource.mSamplerate,
                                command.FloatParam1, // volume
                                command.FloatParam2, // pan
                                command.FloatParam3, // pitch
                                command.FloatParam4, // position
                                command.BoolParam1  // loop
                            );

                            if (voiceHandle >= 0)
                            {
                                lock (stateLock)
                                {
                                    if (voiceStates.TryGetValue(command.Handle, out var state))
                                    {
                                        state.audioSource = command.AudioSource;
                                        state.voiceHandle = voiceHandle;
                                    }
                                }
                            }
                            else
                            {
                                // Failed to play, remove state
                                lock (stateLock)
                                {
                                    voiceStates.Remove(command.Handle);
                                }
                            }
                        }
                        break;

                    case CommandType.Stop:
                        {
                            lock (stateLock)
                            {
                                if (voiceStates.TryGetValue(command.Handle, out var state))
                                {
                                    mixer.Stop(state.voiceHandle);
                                    voiceStates.Remove(command.Handle);
                                }
                            }
                        }
                        break;

                    case CommandType.Pause:
                        {
                            lock (stateLock)
                            {
                                if (voiceStates.TryGetValue(command.Handle, out var state))
                                {
                                    mixer.Pause(state.voiceHandle);
                                }
                            }
                        }
                        break;

                    case CommandType.Resume:
                        {
                            lock (stateLock)
                            {
                                if (voiceStates.TryGetValue(command.Handle, out var state))
                                {
                                    mixer.Resume(state.voiceHandle);
                                }
                            }
                        }
                        break;

                    case CommandType.SetVolume:
                        {
                            lock (stateLock)
                            {
                                if (voiceStates.TryGetValue(command.Handle, out var state))
                                {
                                    mixer.SetVolume(state.voiceHandle, command.FloatParam1);
                                }
                            }
                        }
                        break;

                    case CommandType.SetPan:
                        {
                            lock (stateLock)
                            {
                                if (voiceStates.TryGetValue(command.Handle, out var state))
                                {
                                    mixer.SetPan(state.voiceHandle, command.FloatParam1);
                                }
                            }
                        }
                        break;

                    case CommandType.SetPitch:
                        {
                            lock (stateLock)
                            {
                                if (voiceStates.TryGetValue(command.Handle, out var state))
                                {
                                    mixer.SetPitch(state.voiceHandle, command.FloatParam1);
                                }
                            }
                        }
                        break;

                    case CommandType.SetPosition:
                        {
                            lock (stateLock)
                            {
                                if (voiceStates.TryGetValue(command.Handle, out var state))
                                {
                                    mixer.SetPosition(state.voiceHandle, command.FloatParam1);
                                }
                            }
                        }
                        break;
                }
            }
        }

        private List<int> voiceStatesToRemove = new List<int>();

        private void UpdateShadowPositions()
        {
            lock (stateLock)
            {
                bool hasVoiceStatesToRemove = false;
                foreach (var kvp in voiceStates)
                {
                    int handle = kvp.Key;
                    var state = kvp.Value;

                    // Skip if voice hasn't been initialized yet
                    if (state.audioSource == null)
                        continue;

                    // Get current position from mixer (now returns stream position)
                    double position = mixer.GetPosition(state.voiceHandle);
                    state.position = position;

                    // Check if voice has ended
                    if (position >= state.audioSource.mAudioDataLength / (state.audioSource.mChannels * state.audioSource.mSamplerate) &&
                        (state.audioSource.mFlags & AudioSourceInstance.FLAGS.LOOPING) == 0)
                    {
                        hasVoiceStatesToRemove = true;
                        voiceStatesToRemove.Add(handle);
                    }
                }

                // Remove ended voices
                if (hasVoiceStatesToRemove)
                {
                    foreach (int handle in voiceStatesToRemove)
                    {
                        voiceStates.Remove(handle);
                    }
                    voiceStatesToRemove.Clear();
                }
            }
        }

        public static AudioResource CreateFromData(float[] data, int channels, float sampleRate)
        {
            if (data == null || channels <= 0 || sampleRate <= 0)
                return null;

            return new AudioResource
            {
                audioData = data,
                channels = channels,
                sampleRate = sampleRate,
                duration = data.Length / (channels * sampleRate)
            };
        }
    }
}