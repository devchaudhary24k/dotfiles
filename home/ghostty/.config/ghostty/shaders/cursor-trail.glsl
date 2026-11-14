// Cursor trail for Ghostty. When the cursor jumps (a command finishes, you
// move to another line, the prompt redraws), a short streak in the cursor's
// colour runs from where it was to where it is, and fades in about 0.2 s.
// Moves of a cell or two, as when typing, draw nothing.
//
// Uses Ghostty's cursor uniforms (1.2 and later). config.ghostty loads it with
// `custom-shader`; delete that line to turn it off.

const float DURATION = 0.22; // seconds until the streak is gone
const float MIN_JUMP = 2.5;  // in cursor widths; shorter moves draw nothing
const float OPACITY = 0.6;   // the streak at its brightest, next to the cursor

// Signed distance from p to a box centred on the origin.
float sdBox(vec2 p, vec2 halfSize) {
    vec2 d = abs(p) - halfSize;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float easeOutCubic(float x) {
    return 1.0 - pow(1.0 - x, 3.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    fragColor = texture(iChannel0, fragCoord / iResolution.xy);

    // .xy is the cursor's top-left corner (y grows upwards); use centres.
    vec2 halfSize = iCurrentCursor.zw * 0.5;
    vec2 head = iCurrentCursor.xy + vec2(halfSize.x, -halfSize.y);
    vec2 tail = iPreviousCursor.xy + vec2(iPreviousCursor.z, -iPreviousCursor.w) * 0.5;

    float progress = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    if (progress >= 1.0 || distance(head, tail) < MIN_JUMP * max(iCurrentCursor.z, 1.0)) {
        return;
    }

    // The streak is the cursor's box swept from the tail to the head; the
    // tail catches up with the head as it fades.
    vec2 start = mix(tail, head, easeOutCubic(progress));
    vec2 path = head - start;
    float along = clamp(dot(fragCoord - start, path) / max(dot(path, path), 1e-4), 0.0, 1.0);
    float dist = sdBox(fragCoord - (start + path * along), halfSize);

    float inside = 1.0 - smoothstep(-0.5, 0.5, dist); // soft one-pixel edge
    float alpha = inside * OPACITY * along * (1.0 - progress); // fainter towards the tail
    fragColor = mix(fragColor, vec4(iCurrentCursorColor.rgb, 1.0), alpha);
}
