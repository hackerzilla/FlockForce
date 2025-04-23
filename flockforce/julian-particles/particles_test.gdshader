shader_type particles;

float rand_from_seed(in uint seed) {
  int k;
  int s = int(seed);
  if (s == 0)
	s = 305420679;
  k = s / 127773;
  s = 16807 * (s - k * 127773) - 2836 * k;
  if (s < 0)
	s += 2147483647;
  seed = uint(s);
  return float(seed % uint(65536)) / 65535.0;
}

uint hash(uint x) {
  x = ((x >> uint(16)) ^ x) * uint(73244475);
  x = ((x >> uint(16)) ^ x) * uint(73244475);
  x = (x >> uint(16)) ^ x;
  return x;
}

void start() {
	// Called when a particle is spawned.
}

void process() {
	// Called every frame on existing particles (according to the Fixed FPS property).
}
