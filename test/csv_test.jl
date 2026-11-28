# Tests for csv.jl. Run them with `julia -O0 --project=. test/csv_test.jl`.
# They write small CSV files into a temporary folder.

@use Test: @test, @testset
@use "../blocks/csv" => C

const dir = mktempdir()
file(name, text) = (path = joinpath(dir, name); write(path, text); path)

const plain = file("prices.csv", "Item,Price,Stock\nPaint,\$42.50,12\nTimber,\$8,340\nNails,\$3.20,\n")
const quoted = file("notes.csv", """
Item,Note,Price
Paint,"Two coats, low sheen",42.5
Timber,"The ""good"" pine
from the yard",8
"Nails, 50 mm",,3.2
""")
const long = file("long.csv", "Day,Rain\n" * join(("$d,$(d % 7) mm" for d in 1:100), "\n") * "\n")
const tabs = file("rooms.tsv", "Room\tLong\tWide\nKitchen\t4\t3\nLounge, big\t6\t5\n")
const empty = file("empty.csv", "")

@testset "the cells of a row" begin
  @test C.cells("a,b,c", ',') == ["a", "b", "c"]
  @test C.cells("a,\"b, c\",d", ',') == ["a", "b, c", "d"]
  @test C.cells("\"He said \"\"no\"\"\",2", ',') == ["He said \"no\"", "2"]
  @test C.cells("a,,", ',') == ["a", "", ""]
  @test C.cells("a\tb,c", '\t') == ["a", "b,c"]
end

@testset "the mark between the cells" begin
  @test C.mark("a,b,c") == ',' && C.mark("a\tb\tc") == '\t' && C.mark("a;b;c") == ';'
  # The mark that the row has most of
  @test C.mark("Room, big\tLong\tWide") == '\t'
  # A mark in quotes doesn't count
  @test C.mark("\"Name, first, last\";Price") == ';'
  # A row with no mark has one cell
  @test C.mark("Name") == ','
end

@testset "the rows of a file" begin
  @test C.records("a,b\nc,d\n") == ["a,b", "c,d"]
  # A line break in quotes is part of a cell
  @test C.records("a,\"b\nc\"\nd,e") == ["a,\"b\nc\"", "d,e"]
  # A line with nothing on it is no row
  @test C.records("a\n\n  \nb\n\n") == ["a", "b"]
  @test C.records("a\nb\nc\nd", most=2) == ["a", "b"]
  @test isempty(C.records(""))
end

@testset "a plain file" begin
  t = C.load(plain)
  @test t.problem == "" && !t.more
  @test t.rows == [["Item", "Price", "Stock"], ["Paint", "\$42.50", "12"], ["Timber", "\$8", "340"], ["Nails", "\$3.20", ""]]
  # The columns of numbers. A cell with nothing in it doesn't count.
  @test t.numbers == [false, true, true]
end

@testset "cells in quotes" begin
  t = C.load(quoted)
  @test t.problem == "" && length(t.rows) == 4
  @test t.rows[2] == ["Paint", "Two coats, low sheen", "42.5"]
  @test t.rows[3] == ["Timber", "The \"good\" pine\nfrom the yard", "8"]
  @test t.rows[4] == ["Nails, 50 mm", "", "3.2"]
  @test t.numbers == [false, false, true]
end

@testset "a long file and a file with tabs" begin
  t = C.load(long)
  @test length(t.rows) == 101 && t.rows[end] == ["100", "2 mm"] && !t.more
  @test t.numbers == [true, true]
  t = C.load(tabs)
  @test t.rows == [["Room", "Long", "Wide"], ["Kitchen", "4", "3"], ["Lounge, big", "6", "5"]]
  @test t.numbers == [false, true, true]
end

@testset "what a table keeps of a file" begin
  # Each row has a cell for each column
  @test C.table("a,b,c\n1\n2,3").rows == [["a", "b", "c"], ["1", "", ""], ["2", "3", ""]]
  # Line ends as Windows writes them, the mark that some apps start a file with, and spaces round a cell
  @test C.table("﻿Item; Price\r\nPaint ; 4\r\n").rows == [["Item", "Price"], ["Paint", "4"]]
  # A table stops at its most rows and its most columns, and says that the file has more
  big = C.table("n\n" * join(1:C.MOST_ROWS+50, "\n"))
  @test length(big.rows) == C.MOST_ROWS + 1 && big.more && big.rows[end] == [string(C.MOST_ROWS)]
  @test !C.table("n\n" * join(1:C.MOST_ROWS, "\n")).more
  @test length(C.table(join(1:60, ",")).rows[1]) == C.MOST_COLUMNS
  @test isempty(C.table("").rows) && isempty(C.table("\n\n").rows)
end

@testset "a file that isn't a table" begin
  @test isempty(C.load(empty).rows) && occursin("empty.csv has no rows", C.load(empty).problem)
  gone = C.load(joinpath(dir, "gone.csv"))
  @test isempty(gone.rows) && occursin("can't find the file gone.csv", gone.problem)
  # A folder, and a file that isn't text
  @test occursin("can't find", C.load(dir).problem)
  @test occursin("isn't a file of text", C.load(file("bytes.csv", UInt8[0x50, 0x4b, 0x00, 0x01, 0xff])).problem)
  @test occursin("isn't a file of text", C.load(file("latin.csv", UInt8[0x61, 0x2c, 0xe9, 0x0a])).problem)
  # A file that's longer than Ladder reads stops at the end of a row
  huge = C.load(file("huge.csv", "n,word\n" * repeat("12345,abcdefghijklmnopqrstuvwxyz\n", C.MOST_BYTES ÷ 32 + 10)))
  @test huge.more && huge.problem == "" && all(row -> row == ["12345", "abcdefghijklmnopqrstuvwxyz"], huge.rows[2:end])
end
