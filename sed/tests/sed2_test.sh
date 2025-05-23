#
# Copyright 2017 Dell EMC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# * Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# $FreeBSD$
#

atf_test_case inplace_hardlink_src
inplace_hardlink_src_head()
{
	atf_set "descr" "Verify -i works with a symlinked source file"
}
inplace_hardlink_src_body()
{
	echo foo > a
	atf_check ln a b
	atf_check sed -i '' -e 's,foo,bar,g' b
	atf_check -o 'inline:bar\n' -s exit:0 cat b
	atf_check -s not-exit:0 stat -q '.!'*
}

atf_test_case inplace_symlink_src
inplace_symlink_src_head()
{
	atf_set "descr" "Verify -i works with a symlinked source file"
}
inplace_symlink_src_body()
{
	echo foo > a
	atf_check ln -s a b
	atf_check -e not-empty -s not-exit:0 sed -i '' -e 's,foo,bar,g' b
	atf_check -s not-exit:0 stat -q '.!'*
}

atf_test_case inplace_command_q
inplace_command_q_head()
{
	atf_set "descr" "Verify -i works correctly with the 'q' command"
}
inplace_command_q_body()
{
	printf '1\n2\n3\n' > a
	atf_check -o 'inline:1\n2\n' sed '2q' a
	atf_check sed -i.bak '2q' a
	atf_check -o 'inline:1\n2\n' cat a
	atf_check -o 'inline:1\n2\n3\n' cat a.bak
	atf_check -s not-exit:0 stat -q '.!'*
}

atf_test_case escape_subst
escape_subst_head()
{
	atf_set "descr" "Verify functional escaping of \\n, \\r, and \\t"
}
escape_subst_body()
{
	printf "a\nt\\\t\n\tb\n\t\tc\r\n" > a
	tr -d '\r' < a > b
	printf "a\tb c\rx\n" > c

#ifdef __APPLE__
	atf_expect_fail "Testing behavior that is not POSIX conformant."
#endif
	atf_check -o 'inline:a\nt\\t\n' sed '/\t/d' a
	atf_check -o 'inline:a\nt\\t\n    b\n        c\r\n' sed 's/\t/    /g' a
	atf_check -o 'inline:a\nt\\t\n\t\tb\n\t\t\t\tc\r\n' sed 's/\t/\t\t/g' a
	atf_check -o 'inline:a\nt\n\tb\n\t\tc\r\n' sed 's/\\t//g' a
	atf_check -o file:b sed 's/\r//' a
	atf_check -o 'inline:abcx\n' sed 's/[ \r\t]//g' c
}

atf_test_case hex_subst
hex_subst_head()
{
	atf_set "descr" "Verify proper conversion of hex escapes"
}
hex_subst_body()
{
	printf "test='foo'" > a
	printf "test='27foo'" > b
	printf "\rn" > c
	printf "xx" > d

#ifdef __APPLE__
	atf_expect_fail "Testing behavior that is not POSIX conformant."
#endif
	atf_check -o 'inline:test="foo"' sed 's/\x27/"/g' a
	atf_check -o "inline:'test'='foo'" sed 's/test/\x27test\x27/g' a

	# Make sure we take trailing digits literally.
	atf_check -o "inline:test=\"foo'" sed 's/\x2727/"/g' b

	# Single digit \x should work as well.
	atf_check -o "inline:xn" sed 's/\xd/x/' c

	# This should get passed through to the underlying regex engine as
	# \xx, which is an invalid escape of an ordinary character.
	atf_check -s exit:1 -e not-empty sed 's/\xx//' d
}

atf_test_case commands_on_stdin
commands_on_stdin_head()
{
	atf_set "descr" "Verify -f -"
}
commands_on_stdin_body()
{
	printf "a\n" > a
	printf "s/a/b/\n" > a_to_b
	printf "s/b/c/\n" > b_to_c
	printf "s/c/d/\n" > ./-
	atf_check -o 'inline:d\n' sed -f a_to_b -f - -f ./- a < b_to_c

	# Verify that nothing is printed if there are no input files provided.
	printf 'i\\\nx' > insert_x
	atf_check -o 'empty' sed -f - < insert_x
}

atf_test_case bracket_y
bracket_y_head()
{
	atf_set "descr" "Verify '[' is ordinary character for 'y' command"
}
bracket_y_body()
{
	atf_check -e empty -o ignore echo | sed 'y/[/x/'
	atf_check -e empty -o ignore echo | sed 'y/[]/xy/'
	atf_check -e empty -o ignore echo | sed 'y/[a]/xyz/'
	atf_check -e empty -o "inline:zyx" echo '][a' | sed 'y/[a]/xyz/'
	atf_check -e empty -o "inline:bracket\n" echo 'bra[ke]' | sed 'y/[]/ct/'
	atf_check -e empty -o "inline:bracket\n" \
	    echo 'bra[ke]' | sed 'y[\[][ct['
}

atf_test_case enhanced
enhanced_head()
{
	atf_set "descr" "Verify -H"
}
enhanced_body()
{
	echo "0_0" >input
	# enhanced features such as \< and \d are disabled by default
	atf_check -o inline:"0_0\n" sed -e 's/\<\d/o/' <input
	atf_check -o inline:"0_0\n" sed -E -e 's/\<\d/o/' <input
	# -H enables enhanced features
	atf_check -o inline:"o_0\n" sed -H -e 's/\<\d/o/' <input
	# -H alone does not enable extended syntax
	atf_check -o inline:"0_0\n" sed -H -e 's/\<(\d)/o/' <input
	# -EH enables extended syntax with enhanced features
	atf_check -o inline:"o_0\n" sed -EH -e 's/\<(\d)/o/' <input
	# order of -E and -H does not matter
	atf_check -o inline:"o_0\n" sed -HE -e 's/\<(\d)/o/' <input
}

atf_init_test_cases()
{
	atf_add_test_case inplace_command_q
	atf_add_test_case inplace_hardlink_src
	atf_add_test_case inplace_symlink_src
	atf_add_test_case escape_subst
	atf_add_test_case commands_on_stdin
	atf_add_test_case hex_subst
	atf_add_test_case bracket_y
	atf_add_test_case enhanced
}
