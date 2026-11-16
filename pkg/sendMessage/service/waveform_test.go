package send_service

import (
	"encoding/binary"
	"testing"
)

func TestNormalizeWaveform(t *testing.T) {
	if normalizeWaveform([]byte{1, 2, 3}) != nil {
		t.Fatal("expected nil for wrong length")
	}

	in := make([]byte, 64)
	in[0] = 50
	in[1] = 200 // clamp to 100
	out := normalizeWaveform(in)
	if out == nil {
		t.Fatal("expected normalized waveform")
	}
	if out[0] != 50 || out[1] != 100 {
		t.Fatalf("got %d, %d", out[0], out[1])
	}
}

func TestWaveformFromPCM_VariesWithAmplitude(t *testing.T) {
	// 128 samples: first half silent, second half near-full scale
	pcm := make([]byte, 128*2)
	for i := 64; i < 128; i++ {
		binary.LittleEndian.PutUint16(pcm[i*2:], uint16(int16(30000)))
	}

	w := waveformFromPCM(pcm, 64)
	if len(w) != 64 {
		t.Fatalf("len=%d", len(w))
	}
	if w[0] != 0 {
		t.Fatalf("first bucket should be silent, got %d", w[0])
	}
	if w[63] < 80 {
		t.Fatalf("last bucket should be loud, got %d", w[63])
	}
	// Must not be identical flat pattern
	same := true
	for i := 1; i < len(w); i++ {
		if w[i] != w[0] {
			same = false
			break
		}
	}
	if same {
		t.Fatal("waveform should vary with amplitude")
	}
}
