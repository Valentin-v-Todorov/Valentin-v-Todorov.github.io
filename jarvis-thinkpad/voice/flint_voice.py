#!/usr/bin/env python3
"""flint_voice: a wake phrase and Linux music ducking for backtalk, without editing backtalk.

Loaded by flint_voice.pth in backtalk's virtualenv (voice/install.sh puts both there), so it
runs at every start of that interpreter and patches three things the moment backtalk imports
them, leaving Jared's files untouched so update.sh keeps working:

  backtalk.ears.Ears.listen_once    hands-free utterances not addressed to the agent are dropped
  backtalk.signals.reply_done       remembers when the agent last finished speaking
  backtalk.mouth.Mouth.__init__     swaps the macOS-only Spotify ducker for a Linux one (mpv, MPRIS)

Push-to-talk is untouched: holding the key always gets you heard. Typed input is untouched.
Only the open microphone ("mic_mode": "open", or "go hands free") goes through the wake filter.

How the filter decides (see Matcher.address):
  - the agent's name (or any of "wake_words") within the first four or the last three words
    makes the utterance addressed: "Flint, what time is it", "hey Flint", "play some music, Flint";
  - names are matched loosely, so "Clint" and "Flynt" (what the transcriber sometimes hears) count;
  - an addressed utterance that is only a summons ("Flint?", "Flint, question for you", "I have a
    job for you Flint") gets a short spoken acknowledgement and opens the conversation window;
  - for "wake_window_s" seconds after an addressed utterance, and after each reply the agent
    finishes speaking, the next utterance needs no name (a normal back-and-forth);
  - everything else is logged as "not for me" and never reaches the agent.

Settings, in backtalk.json (backtalk's loader keeps unknown keys):
  "wake_words":    ["flint", "hey flint"]   words that address the agent; "name" is always one
  "wake_window_s": 30                        the follow-up window, seconds
  "wake_required": true                      false = plain hands-free listening (everything goes through)
  "wake_ack":      ["Yes?", "Listening."]    spoken for a summons
  "duck_music":    true                      false = never touch other players' volume

    python -m flint_voice --selftest         runs the matcher against the built-in cases
"""
import difflib
import json
import os
import random
import re
import shutil
import socket
import subprocess
import sys
import threading
import time

__version__ = "1.0"
_LINUX = sys.platform.startswith("linux")

MOUTH = None          # the live backtalk.mouth.Mouth, once one exists
WAKE = None           # the Wake instance, built from backtalk's config on first use

# ----------------------------------------------------------------------------- matching
_HEAD_FILLERS = {"hey", "hi", "hello", "ok", "okay", "yo", "oi", "so", "um", "uh", "and", "now",
                 "right", "well", "alright", "excuse", "me", "please", "psst",
                 # Bulgarian
                 "ей", "хей", "окей", "добре", "ало", "моля", "и", "а", "е", "ами", "така", "виж", "слушай",
                 "здравей", "здрасти", "извинявай", "извинете"}
_AFTER_FILLERS = {"um", "uh", "so", "hey", "please", "ами", "моля", "значи"}
_SUMMONS = {
    "", "question", "question for you", "a question for you", "i have a question for you",
    "i have a question", "i've got a question for you", "i've got a question", "i got a question",
    "quick question", "i have a job for you", "i've got a job for you", "i got a job for you",
    "job for you", "a job for you", "i have a job", "i have a task for you", "task for you",
    "i have something for you", "are you there", "you there", "are you here", "there", "listen",
    "listen up", "listen to me", "wake up", "hello", "hi", "hey", "come here", "can you hear me",
    "do you hear me", "i need you", "need you", "i need your help", "help me", "come in",
    "you awake", "are you awake", "over here", "hello there", "yo", "hey there", "you up",
    # Bulgarian
    "въпрос", "имам въпрос", "имам един въпрос", "въпрос за теб", "един въпрос", "имам задача за теб",
    "задача за теб", "имам работа за теб", "работа за теб", "имам нещо за теб", "тук ли си", "чуваш ли ме",
    "чуваш ли", "слушай", "слушаш ли", "слушай ме", "ела", "ела тук", "здравей", "здрасти", "ей", "ало",
    "трябваш ми", "имам нужда от теб", "събуди се", "буден ли си", "помогни ми", "чуй ме",
}
_ACKS_BG = ["Да?", "Слушам.", "Кажи."]
_CYRILLIC = re.compile(r"[Ѐ-ӿ]")
_LAT2CYR = [("sh", "ш"), ("ch", "ч"), ("zh", "ж"), ("ts", "ц"), ("ya", "я"), ("yu", "ю"), ("kh", "х"), ("ph", "ф"),
            ("a", "а"), ("b", "б"), ("c", "к"), ("d", "д"), ("e", "е"), ("f", "ф"), ("g", "г"), ("h", "х"), ("i", "и"),
            ("j", "дж"), ("k", "к"), ("l", "л"), ("m", "м"), ("n", "н"), ("o", "о"), ("p", "п"), ("q", "к"), ("r", "р"),
            ("s", "с"), ("t", "т"), ("u", "у"), ("v", "в"), ("w", "в"), ("x", "кс"), ("y", "й"), ("z", "з")]


def has_cyrillic(text: str) -> bool:
    return bool(_CYRILLIC.search(text or ""))


def to_cyrillic(word: str) -> str:
    """A Latin name the way the Bulgarian transcriber will spell it ("flint" -> "флинт"). Rough on purpose:
    the matcher is loose, and you can always list the exact spelling in wake_words."""
    out, s = "", word.lower()
    while s:
        for lat, cyr in _LAT2CYR:
            if s.startswith(lat):
                out += cyr; s = s[len(lat):]; break
        else:
            out += s[0]; s = s[1:]
    return out


def _norm_token(tok: str) -> str:
    t = re.sub(r"[^\w']+", "", tok.lower()).replace("_", "")
    if t.endswith("'s"):
        t = t[:-2]
    return t.strip("'")


def _norm_phrase(text: str) -> str:
    return " ".join(t for t in (_norm_token(x) for x in text.split()) if t)


def _same(tok: str, word: str) -> bool:
    """Loose equality: the transcriber writes a name it has never seen the way it sounds."""
    if tok == word:
        return True
    if len(word) >= 4 and len(tok) >= 3:
        return difflib.SequenceMatcher(None, tok, word).ratio() >= 0.8
    return False


class Matcher:
    def __init__(self, words):
        self.words = []
        for w in words:
            toks = tuple(t for t in (_norm_token(x) for x in str(w).split()) if t)
            if toks and toks not in self.words:
                self.words.append(toks)

    def spans(self, toks):
        out = []
        for w in self.words:
            n = len(w)
            for i in range(0, len(toks) - n + 1):
                if all(_same(toks[i + k], w[k]) for k in range(n)):
                    out.append((i, i + n))
        return out

    def address(self, text: str):
        """-> (addressed, remainder). The remainder is the utterance without the summons words,
        original spelling kept, first letter capitalised."""
        raw = text.split()
        toks = [_norm_token(t) for t in raw]
        n = len(toks)
        # A name counts at the head (only fillers before it, or a short utterance with the name
        # in its first four words) or at the tail (within the last three words). A name in the
        # middle of a long sentence is someone talking ABOUT the agent, not to it.
        spans = [s for s in self.spans(toks)
                 if all(t in _HEAD_FILLERS for t in toks[:s[0]])
                 or (n <= 8 and s[0] <= 3)
                 or s[1] >= n - 2]
        if not spans:
            return False, text
        drop = set()
        for a, b in spans:
            drop.update(range(a, b))
            if a <= 3:
                j = a - 1
                while j >= 0 and toks[j] in _HEAD_FILLERS:
                    drop.add(j)
                    j -= 1
                j = b
                while j < n and toks[j] in _AFTER_FILLERS:
                    drop.add(j)
                    j += 1
        keep = [raw[i] for i in range(n) if i not in drop]
        rem = " ".join(keep).strip(" ,.;:!?-")
        if rem:
            rem = rem[0].upper() + rem[1:]
        return True, rem


class Wake:
    def __init__(self, cfg: dict):
        name = str(cfg.get("name") or "").strip().lower()
        words = [str(w).strip().lower() for w in (cfg.get("wake_words") or []) if str(w).strip()]
        if name and name not in words:
            words.insert(0, name)
        # a second language spelled in Cyrillic: the transcriber writes the name the way it sounds
        if name and not has_cyrillic(name) and str(cfg.get("second_language") or "bg") and not any(has_cyrillic(w) for w in words):
            cyr = to_cyrillic(name)
            words += [cyr, "хей " + cyr, "ей " + cyr]
        self.matcher = Matcher(words)
        self.window = float(cfg.get("wake_window_s", 30) or 0)
        self.required = bool(cfg.get("wake_required", True))
        self.acks = [str(a) for a in (cfg.get("wake_ack") or ["Yes?", "Listening.", "Go ahead."])]
        self.last_addressed = 0.0
        self.last_reply_end = 0.0

    def in_window(self, now: float) -> bool:
        ref = max(self.last_addressed, self.last_reply_end)
        return ref > 0 and (now - ref) < self.window

    def filter(self, text: str) -> str:
        """An open-mic transcript -> what backtalk should handle ("" = nothing heard)."""
        if not self.required or not text:
            return text
        now = time.monotonic()
        addressed, rem = self.matcher.address(text)
        if addressed:
            self.last_addressed = now
            if _norm_phrase(rem) in _SUMMONS:
                _log(f"[wake] summoned: {text!r}")
                _say(random.choice(_ACKS_BG if has_cyrillic(text) else self.acks))
                return ""
            _log(f"[wake] for me: {text!r}")
            return rem or text
        if self.in_window(now):
            _log(f"[wake] follow-up: {text!r}")
            self.last_addressed = now
            return text
        _log(f"[wake] not for me: {text[:80]!r}")
        return ""


def wake() -> Wake:
    global WAKE
    if WAKE is None:
        try:
            from backtalk.config import CFG
        except Exception:
            CFG = {}
        WAKE = Wake(CFG)
        _log(f"[wake] listening for {', '.join(' '.join(w) for w in WAKE.matcher.words)} "
             f"(window {WAKE.window:g}s{'' if WAKE.required else ', not required'})")
    return WAKE


def _log(msg: str):
    try:
        from backtalk.vlog import log
        log(msg)
    except Exception:
        print(msg, flush=True)


def _say(text: str):
    if MOUTH is not None:
        try:
            MOUTH.say(text)
        except Exception as e:
            _log(f"[wake] could not speak the acknowledgement: {e!r}")


# ----------------------------------------------------------------------------- ducking (Linux)
def _run(args, timeout=1.5):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip() if r.returncode == 0 else None
    except Exception:
        return None


def mpv_socket() -> str:
    return os.environ.get("FLINT_MPV_SOCK") or os.path.join(
        os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "flint-mpv.sock")


def mpv_cmd(cmd, timeout=0.8):
    """One JSON IPC command to the flint-play mpv; its "data", or None."""
    path = mpv_socket()
    if not os.path.exists(path):
        return None
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect(path)
        s.sendall((json.dumps({"command": cmd, "request_id": 4242}) + "\n").encode())
        buf = b""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            chunk = s.recv(65536)
            if not chunk:
                break
            buf += chunk
            for line in buf.split(b"\n"):
                if not line.strip():
                    continue
                try:
                    msg = json.loads(line)
                except ValueError:
                    continue
                if msg.get("request_id") == 4242:
                    return msg.get("data") if msg.get("error") == "success" else None
        return None
    except Exception:
        return None
    finally:
        try:
            s.close()
        except Exception:
            pass


class LinuxDucker:
    """Music dips while the voice talks: the flint-play mpv (over its socket) and every other
    MPRIS player that is playing (over playerctl). Quiet players are left alone. Same interface
    as backtalk.ducking.Ducker, same debounced restore."""
    THRESHOLD = 25
    PCT = 0.45
    DEBOUNCE = 0.6

    def __init__(self, enabled=True):
        self.enabled = enabled
        self._lock = threading.Lock()
        self._orig = {}
        self._timer = None
        self._playerctl = shutil.which("playerctl")

    def _snapshot(self):
        targets = {}
        vol, paused = mpv_cmd(["get_property", "volume"]), mpv_cmd(["get_property", "pause"])
        if isinstance(vol, (int, float)) and paused is False:
            targets["mpv"] = float(vol)
        if self._playerctl:
            for p in (_run([self._playerctl, "-l"]) or "").split():
                if p.startswith("mpv") and "mpv" in targets:
                    continue
                if _run([self._playerctl, "-p", p, "status"]) != "Playing":
                    continue
                v = _run([self._playerctl, "-p", p, "volume"])
                try:
                    targets["mpris:" + p] = float(v) * 100
                except (TypeError, ValueError):
                    pass
        return targets

    def _set(self, target, pct):
        if target == "mpv":
            mpv_cmd(["set_property", "volume", round(pct, 1)])
        elif self._playerctl:
            _run([self._playerctl, "-p", target[6:], "volume", f"{pct / 100:.2f}"])

    def speech_start(self):
        if not self.enabled:
            return
        with self._lock:
            if self._timer:
                self._timer.cancel()
                self._timer = None
            if self._orig:
                return
            for t, v in self._snapshot().items():
                if v <= self.THRESHOLD:
                    continue
                new = max(float(self.THRESHOLD), v * self.PCT)
                if new >= v:
                    continue
                self._orig[t] = v
                self._set(t, new)

    def speech_end(self, debounce: float = DEBOUNCE):
        with self._lock:
            if not self._orig:
                return
            if self._timer:
                self._timer.cancel()
            self._timer = threading.Timer(debounce, self._restore)
            self._timer.daemon = True
            self._timer.start()

    def _restore(self):
        with self._lock:
            for t, v in self._orig.items():
                self._set(t, v)
            self._orig = {}
            self._timer = None

    def restore_now(self):
        with self._lock:
            if self._timer:
                self._timer.cancel()
                self._timer = None
        self._restore()


# ----------------------------------------------------------------------------- the patches
def _patch_ears(mod):
    orig = mod.Ears.listen_once

    def listen_once(self, *a, **k):
        text = orig(self, *a, **k)
        if not text:
            return text
        try:
            return wake().filter(text)
        except Exception as e:
            _log(f"[wake] filter error, passing the words through: {e!r}")
            return text
    mod.Ears.listen_once = listen_once


def _patch_signals(mod):
    orig = mod.reply_done

    def reply_done(*a, **k):
        try:
            return orig(*a, **k)
        finally:
            if WAKE is not None:
                WAKE.last_reply_end = time.monotonic()
    mod.reply_done = reply_done


# ----------------------------------------------------------------------------- a second voice (Piper)
_PIPER = None            # the loaded PiperVoice, once


def piper_voice_path() -> str:
    try:
        from backtalk.config import CFG
        p = str(CFG.get("piper_voice") or "")
    except Exception:
        p = ""
    if not p:
        p = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"),
                         "flint", "models", "piper", "bg_BG-dimitar-medium.onnx")
    return os.path.expanduser(p)


def piper_ready() -> bool:
    if not os.path.exists(piper_voice_path()):
        return False
    try:
        import piper  # noqa: F401
        return True
    except ImportError:
        return False


def stream_piper(text: str):
    """One sentence in the second language -> (rate, int16 pcm) chunks, like backtalk's Kokoro path."""
    global _PIPER
    import numpy as np
    from piper import PiperVoice, SynthesisConfig
    if _PIPER is None:
        _PIPER = PiperVoice.load(piper_voice_path())
        _log(f"[voice] second-language voice loaded: {os.path.basename(piper_voice_path())}")
    try:
        from backtalk.config import CFG
        speed = float(CFG.get("speed") or 1.0)
    except Exception:
        speed = 1.0
    cfg = SynthesisConfig(length_scale=1.0 / max(0.5, min(2.0, speed)))
    for chunk in _PIPER.synthesize(text, syn_config=cfg):
        pcm = np.frombuffer(chunk.audio_int16_bytes, dtype=np.int16)
        if pcm.size:
            yield chunk.sample_rate, pcm


def _patch_mouth(mod):
    orig = mod.Mouth.__init__

    def __init__(self, *a, **k):
        global MOUTH
        orig(self, *a, **k)
        MOUTH = self
        if _LINUX:
            try:
                from backtalk.config import CFG
                enabled = bool(CFG.get("duck_music", True))
            except Exception:
                enabled = True
            self.ducker = LinuxDucker(enabled)
    mod.Mouth.__init__ = __init__

    # Cyrillic sentences go to the Piper voice (Kokoro has no Bulgarian); ElevenLabs, when on, speaks every language itself
    orig_synth = getattr(mod, "synth_stream", None)
    if orig_synth is None:
        return
    ready = getattr(mod, "_elevenlabs_ready", lambda: False)

    def synth_stream(text, timeout=30.0):
        if has_cyrillic(text) and not ready() and piper_ready():
            try:
                yield from stream_piper(text)
                return
            except Exception as e:
                _log(f"[voice] piper failed ({str(e)[:80]}); falling back")
        yield from orig_synth(text, timeout)
    mod.synth_stream = synth_stream


_PATCHES = {"backtalk.ears": _patch_ears, "backtalk.signals": _patch_signals,
            "backtalk.mouth": _patch_mouth}
_done = set()


class _Loader:
    def __init__(self, inner, name):
        self._inner, self._name = inner, name

    def create_module(self, spec):
        f = getattr(self._inner, "create_module", None)
        return f(spec) if f else None

    def exec_module(self, module):
        self._inner.exec_module(module)
        try:
            _PATCHES[self._name](module)
        except Exception as e:
            print(f"[flint-voice] could not patch {self._name}: {e!r}", file=sys.stderr, flush=True)

    def __getattr__(self, a):
        return getattr(self._inner, a)


class _Finder:
    def find_spec(self, name, path=None, target=None):
        if name not in _PATCHES or name in _done:
            return None
        _done.add(name)
        for f in list(sys.meta_path):
            if f is self or not hasattr(f, "find_spec"):
                continue
            spec = f.find_spec(name, path, target)
            if spec is not None and spec.loader is not None:
                spec.loader = _Loader(spec.loader, name)
                return spec
        return None


def installed() -> bool:
    return any(isinstance(f, _Finder) for f in sys.meta_path)


def install():
    if not installed():
        sys.meta_path.insert(0, _Finder())


# ----------------------------------------------------------------------------- self-test
CASES = [
    # (utterance, addressed, remainder or None for "a summons")
    ("Flint, what time is it?", True, "What time is it"),
    ("Hey Flint, what's the weather like today?", True, "What's the weather like today"),
    ("hey flint", True, None),
    ("Flint?", True, None),
    ("Flint, question for you.", True, None),
    ("I have a job for you, Flint.", True, None),
    ("Okay Flint, play some Eminem.", True, "Play some Eminem"),
    ("Clint, open the browser.", True, "Open the browser"),
    ("Flynt turn the lights off", True, "Turn the lights off"),
    ("Can you help me with this, Flint?", True, "Can you help me with this"),
    ("Flint's memory is in the vault", True, "Memory is in the vault"),
    ("the weather is nice today", False, ""),
    ("I told Flint yesterday that the plan is off and we should move on", False, ""),
    ("print the report", False, ""),
    ("", False, ""),
    # Bulgarian (the transcriber writes the name in Cyrillic)
    ("Флинт, колко е часът?", True, "Колко е часът"),
    ("Хей Флинт, пусни малко музика.", True, "Пусни малко музика"),
    ("Флинт?", True, None),
    ("Флинт, имам въпрос.", True, None),
    ("Имам задача за теб, Флинт.", True, None),
    ("Днес времето е хубаво.", False, ""),
]


def selftest(verbose=True) -> bool:
    m = Matcher(["flint", "hey flint", to_cyrillic("flint"), "хей " + to_cyrillic("flint")])
    assert to_cyrillic("flint") == "флинт", to_cyrillic("flint")
    bad = 0
    for text, want_addr, want_rem in CASES:
        addr, rem = m.address(text)
        summons = addr and _norm_phrase(rem) in _SUMMONS
        ok = addr == want_addr and ((want_rem is None and summons) or
                                    (want_rem is not None and not summons and (not addr or rem == want_rem)))
        if not ok:
            bad += 1
        if verbose or not ok:
            print(f"  {'ok ' if ok else 'BAD'} {text!r:62} -> {'summons' if summons else (rem if addr else '(ignored)')}")
    w = Wake({"name": "Flint", "wake_window_s": 5})
    t0 = time.monotonic()
    assert w.filter("something in the room") == ""
    assert w.filter("Flint, are we good") == "Are we good"
    assert w.filter("and the next thing") == "and the next thing"        # inside the window
    w.last_addressed = t0 - 60
    w.last_reply_end = 0.0
    assert w.filter("now this is not for you") == ""
    w.last_reply_end = time.monotonic()
    assert w.filter("yes please do that") == "yes please do that"        # right after a reply
    if verbose:
        print("  ok  the conversation window (follow-ups after an address and after a reply)")
    print(f"flint_voice {__version__}: {'all cases pass' if not bad else f'{bad} case(s) failed'}")
    return bad == 0


if __name__ == "__main__":
    if "--selftest" in sys.argv or len(sys.argv) == 1:
        sys.exit(0 if selftest("-q" not in sys.argv) else 1)
else:
    if os.environ.get("FLINT_VOICE", "1") != "0":
        install()
