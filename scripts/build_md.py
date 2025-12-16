from pathlib import Path
from string import Template
from datetime import datetime, timezone
from operator import itemgetter

OUTPUT_DIR = Path("/var/www/html")
OUTPUT_FILE = OUTPUT_DIR.joinpath("index.md")

SNAPSHOT_PATH = Path("/snapshots")
FULL_SNAPSHOT_PATH = SNAPSHOT_PATH.joinpath("full")
COMPACTED_SNAPSHOT_PATH = SNAPSHOT_PATH.joinpath("compacted")

HTTPS_SERVER = "https://snapshots.chainweb-community.org/snapshots"
RSYNC_SERVER = "rsync://snapshots.chainweb-community.org/snapshots"

DEFAULT_RSYNC_LINK  = "rsync://snapshots.chainweb-community.org/snapshots/full/2025-12-15/"
DEFAULT_HTTP_LINK = "https://snapshots.chainweb-community.org/snapshots/full/2025-12-15/"

_MD_TEMPLATE = """
# Kadena blockchain snapshots distribution service

Download snapshots of Kadena database.

*Last updated: $last_update*


## Informations
A node requires two databases:
- Blocks Headers and Payload (rocksDB)
- Pact state (sqlite)

All distribbuted Pact states databases are compacted, and only include most recent versions of the Pact state.
The Pact database is roughly 40 Gb. As such a node running this Pact state must have the config option fullHistoricPactState set to  `false`.


For the Blocks datatabse (rocksDB), two flavors are supplied:
- The full datatase (450 Gb). Suitable for every purposes, include general purpose nodes, indexers, ...
- The compacted database (1Gb), which only includes headers and most recent blocks content. Some basic features of the node like `/pool` or `/spv` might not work properly.
Suitable for miners.

**Note: Compacted RocksDB database is currently incompatible with chainweb-node 3.0.1**

## Downloading

Downloading directly via HTTP is possible. But Rsync is definitvely more reliable and recommended.

Examples:
```
rsync -vr $last_rsync_url .
```

```
wget -r -nH --cut-dirs=3 --reject "index.html*" $last_http_url
```

## Snapshots

### Full database

|      | Snapshot Date |  Size | Sqlite Comp. Height | RocksDB Comp. Height | HTTPS | Rsync |
| -----| --------------| ----- | ------------------- | -------------------- | ----- | ----- |
$full_rows

### Compacted database

|      | Snapshot Date |  Size | Sqlite Comp. Height | RocksDB Comp. Height | HTTPS | Rsync |
| -----| --------------| ----- | ------------------- | -------------------- | ----- | ----- |
$compacted_rows

"""

MD_TEMPLATE = Template(_MD_TEMPLATE)


def has_sqlite(snap_dir):
  return snap_dir.joinpath("0", "sqlite", "pact-v1-chain-0.sqlite").is_file()

def has_rocksdb(snap_dir):
  rocks_dir = snap_dir.joinpath("0", "rocksDb")
  manifests_files = rocks_dir.glob("MANIFEST-*")
  sst_files = rocks_dir.glob("*.sst")
  current_file = rocks_dir.joinpath("CURRENT")
  return current_file.is_file() and any(True for _ in manifests_files) and any(True for _ in sst_files)

def is_chainweb_db(snap_dir):
  return snap_dir.is_dir() and has_sqlite(snap_dir) and has_rocksdb(snap_dir)

def get_snapshot_date(snap_dir):
  try:
    return snap_dir.joinpath("0", "sqlite", "snapshot_date").read_text().strip()
  except:
    return ""

def get_size(snap_dir):
  p_sqlite = snap_dir.joinpath("0", "sqlite")
  p_rocksdb = snap_dir.joinpath("0", "rocksDb")

  def file_size(f): return f.stat().st_size if f.is_file() else 0

  return sum(map(file_size, p_sqlite.glob("*"))) + sum(map(file_size, p_rocksdb.glob("*")))

def get_rocksdb_compact_height(snap_dir):
  try:
    return snap_dir.joinpath("0", "rocksDb", "COMPACTION_HEIGHT").read_text().strip()
  except:
    return "/"

def get_sqlite_compact_height(snap_dir):
  try:
    return snap_dir.joinpath("0", "sqlite", "COMPACTION_HEIGHT").read_text().strip()
  except:
    return "/"

def to_data(snap_dir):
  return {"name":snap_dir.name,
          "size": get_size(snap_dir)//1000000000,
          "sqlite_height": get_sqlite_compact_height(snap_dir),
          "rocksDb_height": get_rocksdb_compact_height(snap_dir),
          "date": get_snapshot_date(snap_dir),
          "http_url": HTTPS_SERVER.rstrip("/") +  "/" + snap_dir.parent.name + "/" + snap_dir.name + "/",
          "rsync_url": RSYNC_SERVER.rstrip("/") + "/" + snap_dir.parent.name + "/" +snap_dir.name + "/"}

def get_snapshots_directories(base_dir):
  return filter(is_chainweb_db, base_dir.glob("*"))

def to_sorted(data_in):
  return iter(sorted(data_in, key=itemgetter("name"), reverse=True))

def get_snapshot_data(base_dir):
  return map(to_data, get_snapshots_directories(base_dir))

def first_snapshot_data(base_dir):
  return next(to_sorted(get_snapshot_data(base_dir)), None)

def to_md_row(data):
  return "| {name:s} | {date:s} | {size:d} Gb | {sqlite_height!s} | {rocksDb_height!s} | [HTTPS]({http_url:s}) | {rsync_url:s} |".format(**data)

def gen_md_rows(base_dir):
  return "\n".join(map(to_md_row, to_sorted(get_snapshot_data(base_dir))))


def gen_markdown():
  last_snapshot_data = first_snapshot_data(FULL_SNAPSHOT_PATH)

  return MD_TEMPLATE.substitute(last_rsync_url=last_snapshot_data["rsync_url"] if last_snapshot_data else DEFAULT_RSYNC_LINK,
                                last_http_url=last_snapshot_data["http_url"] if last_snapshot_data else DEFAULT_HTTP_LINK,
                                full_rows=gen_md_rows(FULL_SNAPSHOT_PATH),
                                compacted_rows=gen_md_rows(COMPACTED_SNAPSHOT_PATH),
                                last_update= datetime.now(timezone.utc).isoformat(timespec="seconds")
                                )

md = gen_markdown()
with open(OUTPUT_FILE, "w") as fd:
  fd.write(md)
