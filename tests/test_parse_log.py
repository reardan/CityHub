import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from bench.parse_log import latest_by_company, parse_log, summarize, year_leaders


SAMPLE = """
dbg: [script:4] [0] [I] CHUB STAT y=1971-03-01 t=100 self=0 id=0 name=CityHub val=200000 income=1000 exp=-200 rating=300 cargo=50 bal=80000 loan=50000 t=1 r=2 p=3 s=0
dbg: [script:4] [1] [I] CHUB STAT y=1971-03-01 t=100 self=-1 id=1 name=AAAHogEx val=180000 income=2000 exp=-100 rating=400 cargo=40 bal=90000 loan=0 t=-1 r=-1 p=-1 s=-1
dbg: [script:4] [0] [I] CHUB STAT y=1972-01-01 t=200 self=0 id=0 name=CityHub val=400000 income=5000 exp=-800 rating=500 cargo=90 bal=120000 loan=0 t=2 r=3 p=4 s=0
dbg: [script:4] [gs] [I] CHUB CUT y=1972-01-01 t=200
dbg: [script:4] [0] [E] CHUB FAIL y=1970-06-01 t=10 reason=noise err=ERR_LOCAL_AUTHORITY_REFUSES
dbg: [script:4] [0] [I] CHUB PATH y=1970-07-01 t=20 src=1 dest=2 w=2 exp=100 ok=1 len=40 manh=20
"""


def test_parse_stat_and_cut() -> None:
    parsed = parse_log(SAMPLE)
    assert parsed["cut"] is True
    assert len(parsed["stats"]) == 3
    latest = latest_by_company(parsed["stats"])
    assert latest["CityHub"]["val"] == "400000"
    assert latest["AAAHogEx"]["val"] == "180000"


def test_fail_and_path() -> None:
    parsed = parse_log(SAMPLE)
    assert parsed["fails"][0]["reason"] == "noise"
    assert parsed["paths"][0]["ok"] == "1"
    text = summarize(parsed)
    assert "FAIL noise=1" in text
    assert "PATH ok=1/1" in text


def test_year_leaders() -> None:
    parsed = parse_log(SAMPLE)
    leaders = year_leaders(parsed["stats"], (1971, 1972))
    assert leaders[1971] == "CityHub"
    assert leaders[1972] == "CityHub"


def test_sample_file_roundtrip(tmp_path: Path) -> None:
    log = tmp_path / "match.log"
    log.write_text(SAMPLE, encoding="utf-8")
    parsed = parse_log(log.read_text(encoding="utf-8"))
    assert len(parsed["stats"]) == 3


if __name__ == "__main__":
    from tempfile import TemporaryDirectory

    test_parse_stat_and_cut()
    test_fail_and_path()
    test_year_leaders()
    with TemporaryDirectory() as tmp:
        test_sample_file_roundtrip(Path(tmp))
    print("ok")
