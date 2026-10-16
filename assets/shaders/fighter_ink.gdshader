shader_type spatial;
render_mode unshaded, cull_front;
uniform float thickness = 0.013;
void vertex() { VERTEX += NORMAL * thickness; }
void fragment() { ALBEDO = vec3(0.012, 0.018, 0.026); }
