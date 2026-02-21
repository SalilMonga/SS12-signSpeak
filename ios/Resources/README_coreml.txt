TemporalHandNet Core ML Handoff

Input:
  name: x
  shape: (1, 16, 126)
  dtype: float32
  meaning: sequence of hand-landmark features for last 16 frames.
           Each frame is 126 floats = 2 hands * 21 landmarks * (x,y,z),
           wrist-relative; missing hands are zero-padded.

Output:
  logits: (1, 3) float32 (apply softmax on-device)
  predicted_index = argmax(logits)
  index->label mapping: id2label.json

Notes:
  This model expects the SAME feature construction as training:
    - per hand: subtract wrist landmark (index 0)
    - z can be 0 if unavailable, but keep consistent (126 dims total)
