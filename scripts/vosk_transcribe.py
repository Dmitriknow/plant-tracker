import json, sys
from vosk import Model, KaldiRecognizer
import wave

AUDIO = sys.argv[1] if len(sys.argv) > 1 else ""
MODEL = r"C:/Users/Dmitriknow_server/AppData/Local/hermes/models/vosk-model-small-ru-0.22"

model = Model(MODEL)
wf = wave.open(AUDIO, "rb")
rec = KaldiRecognizer(model, wf.getframerate())

texts = []
while True:
    data = wf.readframes(4000)
    if len(data) == 0:
        break
    if rec.AcceptWaveform(data):
        r = json.loads(rec.Result())
        if r.get("text"):
            texts.append(r["text"])
r = json.loads(rec.FinalResult())
if r.get("text"):
    texts.append(r["text"])

print("FINAL:", " ".join(texts).strip() if texts else "[[empty]]")