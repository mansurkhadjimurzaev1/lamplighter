shader_type spatial;
// Деревянный пол/столешница интерьера: доски с волокнами, щели, потёртость.
// Доски идут вдоль X; ширина доски — board (м).

uniform vec4 tint : source_color = vec4(0.36, 0.23, 0.13, 1.0);
uniform float board = 0.32;
uniform float wear = 0.5;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float row = floor(p.y / board);
	float seg = floor((p.x + hash(vec2(row, 3.0)) * 3.0) / 2.4);
	float id = hash(vec2(row, seg));
	// волокна вдоль доски
	float grain = noise(vec2(p.x * 1.2, p.y * 38.0 + id * 10.0));
	grain = 0.75 + 0.25 * grain + 0.08 * sin(p.x * 9.0 + noise(p * 6.0) * 4.0);
	// щели между досками и торцами
	float gy = abs(fract(p.y / board) - 0.5) * 2.0;
	float gap = smoothstep(0.93, 0.985, gy);
	float gx = abs(fract((p.x + hash(vec2(row, 3.0)) * 3.0) / 2.4) - 0.5) * 2.0;
	gap = max(gap, smoothstep(0.985, 0.997, gx));
	vec3 c = tint.rgb * (0.82 + 0.3 * id) * grain;
	// потёртость посередине (там, где ходят)
	float worn = noise(p * 0.7) * wear;
	c = mix(c, c * 1.25 + vec3(0.03, 0.02, 0.0), worn * 0.4);
	c *= 1.0 - gap * 0.7;
	ALBEDO = c;
	ROUGHNESS = 0.78 - worn * 0.2;
	SPECULAR = 0.25;
}
