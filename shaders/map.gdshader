// Карта на пергаменте: мир «от руки», туман неизведанного, ожившие области в тёплых тонах.
// mode 0 — круглая мини-карта (повёрнута как камера), 1 — большая карта всего мира.
shader_type canvas_item;

uniform sampler2D base_tex : filter_linear;
uniform sampler2D fog_tex : filter_linear;
uniform vec2 world_min;
uniform vec2 world_size;
uniform int mode = 0;
uniform vec2 center;      // мини-карта: точка мира в центре
uniform float view_radius = 30.0;
uniform vec2 fwd = vec2(0.0, -1.0); // «вверх по экрану» в мире
uniform vec2 aspect = vec2(1.0, 1.0); // большая карта: соотношение сторон
uniform vec4 beacons[5]; // x, z, радиус оживания (0 — не горит)

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 world;
	float mask = 1.0;
	if (mode == 0) {
		vec2 l = (UV - 0.5) * 2.0;
		float r = length(l);
		mask = 1.0 - smoothstep(0.96, 1.0, r);
		vec2 right = vec2(-fwd.y, fwd.x);
		world = center + (right * l.x - fwd * l.y) * view_radius;
	} else {
		world = world_min + UV * world_size;
	}
	vec2 uv = (world - world_min) / world_size;
	vec3 paper = vec3(0.87, 0.79, 0.61) * (0.94 + 0.06 * hash(floor(UV * 300.0)));
	vec3 col = paper;
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		vec3 b = texture(base_tex, uv).rgb;
		float alive = 0.0;
		for (int i = 0; i < 5; i++) {
			if (beacons[i].z > 0.0) {
				alive = max(alive, 1.0 - smoothstep(beacons[i].z - 6.0, beacons[i].z, distance(world, beacons[i].xy)));
			}
		}
		b = mix(b, b * vec3(1.05, 1.08, 0.82) + vec3(0.02, 0.04, 0.0), alive * 0.6);
		float f = texture(fog_tex, uv).r;
		// неизведанное — чистый пергамент с лёгкими «облачками»
		col = mix(paper * 0.97, b, smoothstep(0.15, 0.7, f));
	}
	// края пергамента темнее
	if (mode == 0) {
		float r = length((UV - 0.5) * 2.0);
		col *= mix(1.0, 0.78, smoothstep(0.55, 0.98, r));
		col = mix(col, vec3(0.3, 0.2, 0.11), smoothstep(0.9, 0.95, r) * (1.0 - smoothstep(0.97, 1.0, r)));
	} else {
		vec2 e = min(UV, 1.0 - UV);
		col *= mix(0.75, 1.0, smoothstep(0.0, 0.06, min(e.x, e.y)));
	}
	COLOR = vec4(col, mask);
}
