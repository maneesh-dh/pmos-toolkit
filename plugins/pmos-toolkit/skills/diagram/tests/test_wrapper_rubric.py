"""Slim 4-item wrapper rubric prompt tests."""
import pathlib
import sys

HERE = pathlib.Path(__file__).parent
sys.path.insert(0, str(HERE))
import run  # noqa: E402


def test_wrapper_rubric_has_four_items():
    prompt = run.build_wrapper_rubric_prompt()
    for sid in (
        "wrapper-typography-hierarchy",
        "wrapper-text-fit",
        "wrapper-figure-proportion",
        "wrapper-edge-padding",
    ):
        assert sid in prompt, f"missing item: {sid}"


def test_wrapper_rubric_is_single_pass_no_refinement():
    prompt = run.build_wrapper_rubric_prompt()
    assert "refinement" not in prompt.lower()
    assert "loop" not in prompt.lower()


def test_wrapper_rubric_yields_distinct_blocker_count_key():
    prompt = run.build_wrapper_rubric_prompt()
    # Distinct from the diagram rubric's key so callers don't conflate them
    assert "wrapper_blocker_count" in prompt
    assert "wrapper_items" in prompt
