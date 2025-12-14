#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from pathlib import Path
import random
import math

# ============================================================
# Parameters (must match core_tb.v)
# ============================================================
BW = 4
PSUM_BW = 16
ROW = 8
COL = 8
KI_DIM = 3
LEN_KIJ = 9  # 3x3
HEADER = ["0", "0", "0"]

# ============================================================
# Helper functions
# ============================================================
def twos_comp_mask(x: int, bits: int) -> int:
    return x & ((1 << bits) - 1)

def write_file(path: Path, lines):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="\n") as f:
        for h in HEADER:
            f.write(h + "\n")
        for line in lines:
            f.write(line + "\n")

def pack_8nibbles(vals):
    """Pack 8 values (0..15) -> 32-bit binary string"""
    val = 0
    for i, v in enumerate(vals):
        val |= (v & 0xF) << (4 * i)
    return format(val, "032b")

def pack_psum_16bit_same(v: int, simd=False):
    """Pack 8 lanes × psum_bw bits (128 total)
       simd=True: only low 4 bits active per lane
       simd=False: full 16 bits active
    """
    if simd:
        nib = format(v & 0xF, "04b")
        lane = nib + "000000000000"  # low nibble active
    else:
        lane = format(v & 0xFFFF, "016b")
    return lane * COL  # 8 lanes identical

def nij_from_i_kij(i, kij, a_pad_ni_dim, o_ni_dim):
    base = (i // o_ni_dim) * a_pad_ni_dim + (i % o_ni_dim)
    return base + (kij // KI_DIM) * a_pad_ni_dim + (kij % KI_DIM)

def parse_config(cfg_path: Path):
    toks = cfg_path.read_text().split()
    it = iter(toks)
    num_layers = int(next(it))
    num_otiles = int(next(it))
    layers = []
    for _ in range(num_layers):
        len_nij = int(next(it))
        len_onij = int(next(it))
        a_pad_ni_dim = int(next(it))
        o_ni_dim = int(next(it))
        layers.append((len_nij, len_onij, a_pad_ni_dim, o_ni_dim))
    return num_layers, num_otiles, layers

# ============================================================
# Data generation
# ============================================================
def gen_activation(len_nij):
    """8 input channels × len_nij values"""
    act = [[0] * len_nij for _ in range(ROW)]
    for ic in range(ROW):
        for nij in range(len_nij):
            # smooth gradient + slight per-channel offset
            act[ic][nij] = ((nij + ic) % 8) + 1  # 1~8
    return act

def gen_weight():
    """8×8×9 tensor"""
    w = [[[0] * LEN_KIJ for _ in range(ROW)] for _ in range(COL)]
    for oc in range(COL):
        for ic in range(ROW):
            for kij in range(LEN_KIJ):
                base = (oc + ic + kij) % 8
                w[oc][ic][kij] = base - 4  # signed small values -4~3
    return w

def compute_golden(act, w, len_onij, a_pad_ni_dim, o_ni_dim, simd=False):
    lines = []
    for i in range(len_onij):
        psums = [0] * COL
        for kij in range(LEN_KIJ):
            nij = nij_from_i_kij(i, kij, a_pad_ni_dim, o_ni_dim)
            for oc in range(COL):
                acc = 0
                for ic in range(ROW):
                    acc += act[ic][nij] * w[oc][ic][kij]
                psums[oc] += acc
        psums = [max(0, x) for x in psums]  # ReLU
        # identical per lane for stability
        val = int(sum(psums) / COL) & ((1 << PSUM_BW) - 1)
        lines.append(pack_psum_16bit_same(val, simd=simd))
    return lines

# ============================================================
# Main
# ============================================================
def main():
    here = Path(__file__).resolve().parent
    cfg = (here / "../datafiles/config.txt").resolve()
    out_root = (here / "../datafiles").resolve()
    num_layers, num_otiles, layers = parse_config(cfg)
    single = (num_layers == 1 and num_otiles == 1)
    print(f"[INFO] Layers={num_layers}, Otiles={num_otiles}")

    for li, (len_nij, len_onij, a_pad_ni_dim, o_ni_dim) in enumerate(layers):
        act = gen_activation(len_nij)
        w = gen_weight()

        # === Activation files ===
        act_lines = []
        for nij in range(len_nij):
            vals = [act[ic][nij] & 0xF for ic in range(ROW)]
            act_lines.append(pack_8nibbles(vals))
        act2_path = out_root / ("2bit/activation.txt" if single else f"2bit/activation_L{li}.txt")
        act4_path = out_root / ("4bit/activation.txt" if single else f"4bit/activation_L{li}.txt")
        write_file(act2_path, act_lines)
        write_file(act4_path, act_lines)

        # === Each otile ===
        for ot in range(num_otiles):
            for kij in range(LEN_KIJ):
                # weight files
                lines = []
                for oc in range(COL):
                    vals = [w[oc][ic][kij] & 0xF for ic in range(ROW)]
                    lines.append(pack_8nibbles(vals))
                w2_path = out_root / ("2bit/weight_kij%d.txt" % kij if single else f"2bit/weight_L{li}_otile{ot}_kij{kij}.txt")
                w4_path = out_root / ("4bit/weight_kij%d.txt" % kij if single else f"4bit/weight_L{li}_otile{ot}_kij{kij}.txt")
                write_file(w2_path, lines + lines)  # 2bit模式 col*2 行
                write_file(w4_path, lines)          # 4bit模式 col 行

            # === Golden ===
            p2_lines = compute_golden(act, w, len_onij, a_pad_ni_dim, o_ni_dim, simd=True)
            p4_lines = compute_golden(act, w, len_onij, a_pad_ni_dim, o_ni_dim, simd=False)
            p2_path = out_root / ("2bit/psum.txt" if single else f"2bit/psum_L{li}_otile{ot}.txt")
            p4_path = out_root / ("4bit/psum.txt" if single else f"4bit/psum_L{li}_otile{ot}.txt")
            write_file(p2_path, p2_lines)
            write_file(p4_path, p4_lines)

    print(f"[DONE] Generated realistic 2bit+4bit test data under {out_root}")

if __name__ == "__main__":
    main()
