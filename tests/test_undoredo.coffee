# Tests the UndoRedo module

UndoRedo = require "../src/coffee/client/undo_redo"
Ot = require "../src/coffee/shared/ot"
OtText = require "../src/coffee/shared/ottext"
PuzzleUtils = require "../src/coffee/shared/puzzle_utils"

take = OtText.take
skip = OtText.skip
insert = OtText.insert

exports.UndoRedoTest =
    testText: (test) ->
        puzzle = PuzzleUtils.getEmptyPuzzle(3, 3, "test title")
        puzzle.down_clues = "abc"

        ur = new UndoRedo.UndoRedo(puzzle)

        test.deepEqual ur.undo(), null
        test.deepEqual ur.redo(), null

        ur.applyOp(Ot.getClueOp("down", [take(3), insert("1")]), true)
        ur.applyOp(Ot.getClueOp("down", [take(4), insert("2")]), true)

        ur.applyOp(Ot.getClueOp("down", [insert("3"), take(5)]), false)
        ur.applyOp(Ot.getClueOp("down", [insert("4"), take(6)]), false)

        ur.applyOp(Ot.getClueOp("down", [take(7), insert("5")]), true)
        ur.applyOp(Ot.getClueOp("down", [take(8), insert("6")]), true)

        test.deepEqual ur.redo(), null

        test.deepEqual ur.undo(), Ot.getClueOp("down", [take(8), skip(1)])
        test.deepEqual ur.undo(), Ot.getClueOp("down", [take(7), skip(1)])
        test.deepEqual ur.undo(), Ot.getClueOp("down", [take(6), skip(1)])
        test.deepEqual ur.undo(), Ot.getClueOp("down", [take(5), skip(1)])
        test.deepEqual ur.undo(), null

        test.deepEqual ur.redo(), Ot.getClueOp("down", [take(5), insert("1")])
        test.deepEqual ur.redo(), Ot.getClueOp("down", [take(6), insert("2")])
        ur.applyOp(Ot.getClueOp("down", [insert("0"), take(7)]), false)
        test.deepEqual ur.redo(), Ot.getClueOp("down", [take(8), insert("5")])
        test.deepEqual ur.redo(), Ot.getClueOp("down", [take(9), insert("6")])
        test.deepEqual ur.redo(), null

        test.deepEqual ur.undo(), Ot.getClueOp("down", [take(9), skip(1)])
        ur.applyOp(Ot.getClueOp("down", [insert("-"), take(9)]), true)
        test.deepEqual ur.redo(), null

        test.deepEqual ur.undo(), Ot.getClueOp("down", [skip(1), take(9)])
        test.deepEqual ur.undo(), Ot.getClueOp("down", [take(8), skip(1)])
        test.deepEqual ur.undo(), Ot.getClueOp("down", [take(7), skip(1)])
        test.deepEqual ur.undo(), Ot.getClueOp("down", [take(6), skip(1)])
        test.deepEqual ur.undo(), null

        test.done()

    testCellOverride: (test) ->
        puzzle = PuzzleUtils.getEmptyPuzzle(3, 3, "test title")
        puzzle.grid[0][0].contents = "A"

        ur = new UndoRedo.UndoRedo(puzzle)

        ur.applyOp(Ot.opEditCellValue(0, 0, "contents", "B"), true)
        ur.applyOp(Ot.opEditCellValue(0, 0, "contents", "C"), false)

        test.deepEqual ur.undo(), Ot.opEditCellValue(0, 0, "contents", "A")
        test.deepEqual ur.undo(), null

        test.deepEqual ur.redo(), Ot.opEditCellValue(0, 0, "contents", "C")
        test.deepEqual ur.redo(), null

        test.done()
