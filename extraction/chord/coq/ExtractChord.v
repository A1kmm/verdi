Require Import Arith.
Require Import ExtrOcamlBasic.
Require Import ExtrOcamlNatInt.
Require Import ExtrOcamlString.

Require Import Chord.

Definition SUCC_LIST_LEN := 5.

Definition hash (a : addr) : id :=
  a mod 256.

Definition handleNet : addr -> addr -> payload -> data -> res :=
  recv_handler SUCC_LIST_LEN hash.

Definition init : addr -> list addr -> res :=
  start_handler SUCC_LIST_LEN hash.

Definition handleTick : addr -> data -> res :=
  tick_handler hash.

Definition handleTimeout : addr -> addr -> data -> res :=
  timeout_handler hash.

Definition test (a b c : nat) : nat * nat * nat :=
  (a, b, c).

Extraction "Test.ml" test.
Extraction "ExtractedChord.ml" init handleNet handleTick handleTimeout is_request closes_request.