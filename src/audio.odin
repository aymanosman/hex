package main

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

SAMPLE_RATE :: 44100

Sfx :: struct {
	swing, hit, pickup: rl.Sound,
}

sfx: Sfx

audio_init :: proc() {
	rl.InitAudioDevice()
	sfx.swing  = synth_swing()
	sfx.hit    = synth_hit()
	sfx.pickup = synth_pickup()
}

audio_shutdown :: proc() {
	rl.UnloadSound(sfx.swing)
	rl.UnloadSound(sfx.hit)
	rl.UnloadSound(sfx.pickup)
	rl.CloseAudioDevice()
}

play :: proc(s: rl.Sound) {
	// avoid choking the mixer — if this sound is already playing on all
	// its buffers we just skip this one. PlaySound already handles that.
	rl.PlaySound(s)
}

// Short "whoosh" via noise + exponential decay.
synth_swing :: proc() -> rl.Sound {
	return synth(0.08, proc(t, dur: f32) -> f32 {
		env := math.exp(-24 * t)
		return (rand.float32_range(-1, 1)) * env * 0.35
	})
}

// Low thud: a 140 Hz sine drop to 70 Hz, sharp decay.
synth_hit :: proc() -> rl.Sound {
	return synth(0.09, proc(t, dur: f32) -> f32 {
		freq := 140.0 - 70.0 * (t / dur)
		env := math.exp(-30 * t)
		return math.sin(2 * math.PI * f32(freq) * t) * env * 0.6
	})
}

// Pickup: two-note rising square wave.
synth_pickup :: proc() -> rl.Sound {
	return synth(0.14, proc(t, dur: f32) -> f32 {
		freq: f32 = t < dur * 0.5 ? 660 : 988 // E5 → B5
		env := math.exp(-6 * t)
		s := math.sin(2 * math.PI * freq * t)
		square := s > 0 ? f32(0.35) : f32(-0.35)
		return square * env
	})
}

// Common 16-bit mono PCM builder. `sample` returns a value in [-1, 1]
// given (time_in_seconds, duration).
synth :: proc(duration: f32, sample: proc(t, dur: f32) -> f32) -> rl.Sound {
	frame_count := int(f32(SAMPLE_RATE) * duration)
	buf := make([]i16, frame_count)
	defer delete(buf)

	for i in 0 ..< frame_count {
		t := f32(i) / f32(SAMPLE_RATE)
		v := sample(t, duration)
		if v > 1  do v = 1
		if v < -1 do v = -1
		buf[i] = i16(v * 32767)
	}

	wave := rl.Wave {
		frameCount = u32(frame_count),
		sampleRate = SAMPLE_RATE,
		sampleSize = 16,
		channels   = 1,
		data       = raw_data(buf),
	}
	return rl.LoadSoundFromWave(wave)
}
