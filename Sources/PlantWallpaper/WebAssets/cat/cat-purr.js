/* Procedural cat purr synthesis. No samples: a soft motor pulse is built from
   filtered noise, low oscillators, and slow tremolo so it can fade with petting. */
const CatPurr = (() => {
  const MIN_GAIN = 0.0001;

  function create() {
    let ctx = null;
    let master = null;
    let purrGain = null;
    let tremoloGain = null;
    let started = false;
    let enabled = true;
    let target = 0;
    let current = 0;

    function ensureContext() {
      if (ctx) return true;
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      if (!AudioContextClass) return false;
      ctx = new AudioContextClass();

      master = ctx.createGain();
      master.gain.value = 0.0;
      master.connect(ctx.destination);

      const compressor = ctx.createDynamicsCompressor();
      compressor.threshold.value = -38;
      compressor.knee.value = 22;
      compressor.ratio.value = 2.4;
      compressor.attack.value = 0.02;
      compressor.release.value = 0.28;
      compressor.connect(master);

      purrGain = ctx.createGain();
      purrGain.gain.value = MIN_GAIN;
      purrGain.connect(compressor);

      const lowHum = ctx.createOscillator();
      lowHum.type = 'sine';
      lowHum.frequency.value = 62;
      const lowHumGain = ctx.createGain();
      lowHumGain.gain.value = 0.16;
      lowHum.connect(lowHumGain);
      lowHumGain.connect(purrGain);

      const chestHum = ctx.createOscillator();
      chestHum.type = 'triangle';
      chestHum.frequency.value = 31;
      const chestGain = ctx.createGain();
      chestGain.gain.value = 0.13;
      chestHum.connect(chestGain);
      chestGain.connect(purrGain);

      const noise = ctx.createBufferSource();
      noise.buffer = makeBrownNoiseBuffer(ctx, 2.2);
      noise.loop = true;
      const noiseFilter = ctx.createBiquadFilter();
      noiseFilter.type = 'bandpass';
      noiseFilter.frequency.value = 118;
      noiseFilter.Q.value = 0.62;
      const noiseGain = ctx.createGain();
      noiseGain.gain.value = 0.075;
      noise.connect(noiseFilter);
      noiseFilter.connect(noiseGain);
      noiseGain.connect(purrGain);

      const tremolo = ctx.createOscillator();
      tremolo.type = 'sine';
      tremolo.frequency.value = 24.5;
      tremoloGain = ctx.createGain();
      tremoloGain.gain.value = 0.020;
      tremolo.connect(tremoloGain);
      tremoloGain.connect(purrGain.gain);

      lowHum.start();
      chestHum.start();
      noise.start();
      tremolo.start();
      started = true;
      return true;
    }

    function makeBrownNoiseBuffer(audioContext, seconds) {
      const length = Math.max(1, Math.floor(audioContext.sampleRate * seconds));
      const buffer = audioContext.createBuffer(1, length, audioContext.sampleRate);
      const data = buffer.getChannelData(0);
      let last = 0;
      for (let i = 0; i < length; i += 1) {
        const white = Math.random() * 2 - 1;
        last = (last + 0.025 * white) / 1.025;
        data[i] = last * 2.8;
      }
      return buffer;
    }

    function setEnabled(value) {
      enabled = !!value;
      if (!enabled) target = 0;
    }

    function setPurring(value, intensity = 1) {
      if (!enabled || !value) {
        target = 0;
        return;
      }
      if (!ensureContext()) return;
      if (ctx.state === 'suspended') {
        ctx.resume().catch(() => {});
      }
      target = Math.max(0, Math.min(1, intensity));
    }

    function update(dt) {
      if (!started || !master || !purrGain) return;
      const rate = target > current ? 5.2 : 2.8;
      current += (target - current) * Math.min(1, dt * rate);
      const gain = current <= 0.002 ? 0 : 0.040 + current * 0.180;
      master.gain.setTargetAtTime(gain, ctx.currentTime, target > current ? 0.045 : 0.12);
      purrGain.gain.setTargetAtTime(Math.max(MIN_GAIN, 0.82 + current * 0.72), ctx.currentTime, 0.08);
      if (tremoloGain) {
        tremoloGain.gain.setTargetAtTime(0.018 + current * 0.036, ctx.currentTime, 0.08);
      }
      if (current < 0.001 && target === 0) {
        current = 0;
      }
    }

    function status() {
      return {
        enabled,
        started,
        purring: target > 0 || current > 0.01
      };
    }

    return { setEnabled, setPurring, update, status };
  }

  return { create };
})();
