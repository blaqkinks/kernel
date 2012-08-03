#!/bin/bash
#
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy is of the CDDL is also available via the Internet
# at http://www.illumos.org/license/CDDL.
#

#
# Copyright 2010 Chris Love.  All rights reserved.
# Copyright (c) 2012, Joyent, Inc. All rights reserved.
#

checktest()
{
	local actual=$1
	local output=$2
	local test=$3

	if [[ "$a" != "$o" ]]; then
		echo "$CMD: test $test: FAIL"
		echo -e "$CMD: test $test: expected output:\n$o"
		echo -e "$CMD: test $test: actual output:\n$a"
	else
		echo "$CMD: test $test: pass"
	fi
}

# 
# Test cases for 'tail', some based on CoreUtils test cases (validated
# with legacy Solaris 'tail' and/or xpg4 'tail').  Note that this is designed
# to be able to run on BSD systems as well to check our behavior against
# theirs (some behavior that is known to be idiosyncratic to illumos is
# skipped on non-illumos systems).
#
PROG=/usr/bin/tail
CMD=`basename $0`
DIR=""

case $1 in 
    -x)
    	PROG=/usr/xpg4/bin/tail
	;;
    -o)
    	PROG=$2
	;;
    -d)
	DIR=$2
	;;
    -?)
    	echo "Usage: tailtests.sh [-x][-o <override tail executable>]"
	exit 1
	;;
esac

#
# Shut bash up upon receiving a term so we can drop it on our children
# without disrupting the output.
#
trap "exit 0" TERM

echo "$CMD: program is $PROG"

if [[ $DIR != "" ]]; then
	echo "$CMD: directory is $DIR"
fi

o=`echo -e "bcd"`
a=`echo -e "abcd" | $PROG +2c`
checktest "$a" "$o" 1

o=`echo -e ""`
a=`echo "abcd" | $PROG +8c`
checktest "$a" "$o" 2

o=`echo -e "abcd"`
a=`echo "abcd" | $PROG -9c`
checktest "$a" "$o" 3

o=`echo -e "x"`
a=`echo -e "x" | $PROG -1l`
checktest "$a" "$o" 4

o=`echo -e "\n"`
a=`echo -e "x\ny\n" | $PROG -1l`
checktest "$a" "$o" 5

o=`echo -e "y\n"`
a=`echo -e "x\ny\n" | $PROG -2l`
checktest "$a" "$o" 6

o=`echo -e "y"`
a=`echo -e "x\ny" | $PROG -1l`
checktest "$a" "$o" 7

o=`echo -e "x\ny\n"`
a=`echo -e "x\ny\n" | $PROG +1l`
checktest "$a" "$o" 8

o=`echo -e "y\n"`
a=`echo -e "x\ny\n" | $PROG +2l`
checktest "$a" "$o" 9

o=`echo -e "x"`
a=`echo -e "x" | $PROG -1`
checktest "$a" "$o" 10

o=`echo -e "\n"`
a=`echo -e "x\ny\n" | $PROG -1`
checktest "$a" "$o" 11

o=`echo -e "y\n"`
a=`echo -e "x\ny\n" | $PROG -2`
checktest "$a" "$o" 12

o=`echo -e "y"`
a=`echo -e "x\ny" | $PROG -1`
checktest "$a" "$o" 13

o=`echo -e "x\ny\n"`
a=`echo -e "x\ny\n" | $PROG +1`
checktest "$a" "$o" 14

o=`echo -e "y\n"`
a=`echo -e "x\ny\n" | $PROG +2`
checktest "$a" "$o" 15

o=`echo -e "yyz"`
a=`echo -e "xyyyyyyyyyyz" | $PROG +10c`
checktest "$a" "$o" 16

o=`echo -e "y\ny\nz"`
a=`echo -e "x\ny\ny\ny\ny\ny\ny\ny\ny\ny\ny\nz" | $PROG +10l`
checktest "$a" "$o" 17

o=`echo -e "y\ny\ny\ny\ny\ny\ny\ny\ny\nz"`
a=`echo -e "x\ny\ny\ny\ny\ny\ny\ny\ny\ny\ny\nz" | $PROG -10l`
checktest "$a" "$o" 18

#
# For reasons that are presumably as accidental as they are ancient, legacy
# (and closed) Solaris tail(1) allows +c, +l and -l to be aliases for +10c,
# +10l and -10l, respectively.  If we are on SunOS, verify that this silly
# behavior is functional.
#
if [[ `uname -s` == "SunOS" ]]; then
	o=`echo -e "yyz"`
	a=`echo -e "xyyyyyyyyyyz" | $PROG +c`
	checktest "$a" "$o" 16a

	o=`echo -e "y\ny\nz"`
	a=`echo -e "x\ny\ny\ny\ny\ny\ny\ny\ny\ny\ny\nz" | $PROG +l`
	checktest "$a" "$o" 17a

	o=`echo -e "y\ny\ny\ny\ny\ny\ny\ny\ny\nz"`
	a=`echo -e "x\ny\ny\ny\ny\ny\ny\ny\ny\ny\ny\nz" | $PROG -l`
	checktest "$a" "$o" 18a
fi

o=`echo -e "c\nb\na"`
a=`echo -e "a\nb\nc" | $PROG -r`
checktest "$a" "$o" 19

#
# Now we want to do a series of follow tests.
#
if [[ $DIR == "" ]]; then
	tdir=$(mktemp -d -t tailtest.XXXXXXXX || exit 1)
else
	tdir=$(mktemp -d $DIR/tailtest.XXXXXXXX || exit 1)
fi

follow=$tdir/follow
moved=$tdir/follow.moved
out=$tdir/out

#
# First, verify that following works in its most basic sense.
#
echo -e "a\nb\nc" > $follow
$PROG -f $follow > $out 2> /dev/null &
child=$!
sleep 2
echo -e "d\ne\nf" >> $follow
sleep 1
kill $child
sleep 1

o=`echo -e "a\nb\nc\nd\ne\nf\n"`
a=`cat $out`
checktest "$a" "$o" 20
rm $follow

#
# Now verify that following correctly follows the file being moved.
#
echo -e "a\nb\nc" > $follow
$PROG -f $follow > $out 2> /dev/null &
child=$!
sleep 2
mv $follow $moved

echo -e "d\ne\nf" >> $moved
sleep 1
kill $child
sleep 1

o=`echo -e "a\nb\nc\nd\ne\nf\n"`
a=`cat $out`
checktest "$a" "$o" 21
rm $moved

#
# And now truncation with the new offset being less than the old offset.
#
echo -e "a\nb\nc" > $follow
$PROG -f $follow > $out 2> /dev/null &
child=$!
sleep 2
echo -e "d\ne\nf" >> $follow
sleep 1
echo -e "g\nh\ni" > $follow
sleep 1
kill $child
sleep 1

o=`echo -e "a\nb\nc\nd\ne\nf\ng\nh\ni\n"`
a=`cat $out`
checktest "$a" "$o" 22
rm $follow

#
# And truncation with the new offset being greater than the old offset.
#
echo -e "a\nb\nc" > $follow
sleep 1
$PROG -f $follow > $out 2> /dev/null &
child=$!
sleep 2
echo -e "d\ne\nf" >> $follow
sleep 1
echo -e "g\nh\ni\nj\nk\nl\nm\no\np\nq" > $follow
sleep 1
kill $child
sleep 1

o=`echo -e "a\nb\nc\nd\ne\nf\ng\nh\ni\nj\nk\nl\nm\no\np\nq"`
a=`cat $out`
checktest "$a" "$o" 23
rm $follow

#
# Verify that we can follow the moved file and correctly see a truncation.
#
echo -e "a\nb\nc" > $follow
$PROG -f $follow > $out 2> /dev/null &
child=$!
sleep 2
mv $follow $moved

echo -e "d\ne\nf" >> $moved
sleep 1
echo -e "g\nh\ni\nj\nk\nl\nm\no\np\nq" > $moved
sleep 1
kill $child
sleep 1

o=`echo -e "a\nb\nc\nd\ne\nf\ng\nh\ni\nj\nk\nl\nm\no\np\nq"`
a=`cat $out`
checktest "$a" "$o" 24
rm $moved

#
# Verify that capital-F follow properly deals with truncation
#
echo -e "a\nb\nc" > $follow
$PROG -F $follow > $out 2> /dev/null &
child=$!
sleep 2
echo -e "d\ne\nf" >> $follow
sleep 1
echo -e "g\nh\ni" > $follow
sleep 1
kill $child
sleep 1

o=`echo -e "a\nb\nc\nd\ne\nf\ng\nh\ni\n"`
a=`cat $out`
checktest "$a" "$o" 25
rm $follow

#
# Verify that capital-F follow _won't_ follow the moved file and will
# correctly deal with recreation of the original file.
#
echo -e "a\nb\nc" > $follow
$PROG -F $follow > $out 2> /dev/null &
child=$!
sleep 2
mv $follow $moved

echo -e "x\ny\nz" >> $moved
echo -e "d\ne\nf" > $follow
sleep 1
kill $child
sleep 1

o=`echo -e "a\nb\nc\nd\ne\nf\n"`
a=`cat $out`
checktest "$a" "$o" 26
rm $moved

echo "$CMD: completed"

exit $errs

