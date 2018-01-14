#! /usr/bin/gawk -f

# sortmail.awk --- sort a Unix style mailbox by "thread", in date+subject order.
# Use Message-ID header to detect and remove duplicates.  Requires GNU Awk for
# time/date and sorting functions but could be made to run on a POSIX awk
# with some work.
#
# Copyright (C) 2007, 2008, 2011, 2015, 2016 Arnold David Robbins
# arnold@skeeve.com
#
# Sortmail.awk is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
# 
# Sortmail.awk is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA

BEGIN {
	TRUE = 1
	FALSE = 0
	split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", months, " ")
	for (i in months)
		Month[months[i]] = i	# map name to number
	split("31 28 31 30 31 30 31 31 30 31 30 31", MonthDays, " ")
	In_header = FALSE
	
	# These keep --lint happier
	Debug = 0
	MessageNum = 0
	Duplicates = 0
	
	body = ""
	Thread_summary_file = ""
	Last_summary_subject = ""
	if (ARGV[1] == "-s" && (2 in ARGV)) {
		Thread_summary_file = ARGV[2]
		delete ARGV[1]
		delete ARGV[2]
	}
}

{
	Line = $0
	if (Line ~ /^From /) {
		In_header = TRUE
		MessageNum++
		header_line = 1
		Header[MessageNum][header_line++] = Line
		if (MessageNum > 1) {
			Body[MessageNum-1] = body
		}
		body_line = 0
		body = ""
	} else if (In_header) {
		if (Line ~ /^$/) {
			In_header = FALSE
		}
		Header[MessageNum][header_line++] = Line
	} else {
		if (body_line == 0)
			body = Line
		else
			body = body "\n" Line
		body_line++
	}
}

END {
	Body[MessageNum] = body
	for (i = 1; i <= MessageNum; i++) {
		for (j = 1; j in Header[i]; j++) {
			if (Header[i][j] ~ /^[Dd]ate: /) {
				Date[i] = compute_date(Header[i][j])
			} else if (Header[i][j] ~ /^[Ss]ubject: /) {
				subj_line = Header[i][j]
				for (k = j + 1; k in Header[i] && Header[i][k] ~ /^[[:space:]]/; k++)
					subj_line = subj_line "\n" Header[i][k]
				Subject[i] = canonacalize_subject(subj_line)
			} else if (Header[i][j] ~ /^[Mm]essage-[Ii][Dd]: */) {
				message_id_line = Header[i][j]
				if (tolower(message_id_line) ~ /^message-id: *$/) {
					# line is only the header name, get the next line
					message_id_line = message_id_line " " Header[i][j+1]
				}
				line = tolower(message_id_line)
				split(line, linefields)
				
				message_id = linefields[2]
				Mesg_ID[i] = message_id	# needed for disambiguating message
				if (message_id in Message_IDs) {
					printf("Message %d is duplicate of %s (%s)\n",
						i, Message_IDs[message_id],
						message_id) > "/dev/stderr"
					Message_IDs[message_id] = (Message_IDs[message_id] ", " i)
					Duplicates++
				} else {
					Message_IDs[message_id] = i ""
				}
			}
		}
		if (Debug && (Subject[i], Date[i], Mesg_ID[i]) in SubjectDateId) {
			printf(\
		("Message %d: Subject <%s> Date <%s> Message-ID <%s> already in" \
		" SubjectDateId (Message %d, s: <%s>, d <%s> i <%s>)!\n"),
			i, Subject[i], Date[i], Mesg_ID[i],
			SubjectDateId[Subject[i], Date[i], Mesg_ID[i]],
			Subject[SubjectDateId[Subject[i], Date[i], Mesg_ID[i]]],
			Date[SubjectDateId[Subject[i], Date[i], Mesg_ID[i]]],
			Mesg_ID[SubjectDateId[Subject[i], Date[i], Mesg_ID[i]]]) \
				> "/dev/stderr"
		}
		
		SubjectDateId[Subject[i], Date[i], Mesg_ID[i]] = i
		
		if (Debug) {
			printf("\tMessage Num = %d, length(SubjectDateId) = %d\n",
				i, length(SubjectDateId)) > "/dev/stderr"
			if (i != length(SubjectDateId) && ! Printed1) {
				Printed1++
				printf("---> Message %d <---\n", i) > "/dev/stderr"
			}
		}
		if (! (Subject[i] in FirstDates) || FirstDates[Subject[i]] > Date[i])
			FirstDates[Subject[i]] = Date[i]
	}
	if (Debug) {
		printf("length(SubjectDateId) = %d, length(Subject) = %d, length(Date) = %d\n",
			length(SubjectDateId), length(Subject), length(Date)) > "/dev/stderr"
		printf("length(FirstDates) = %d\n", length(FirstDates)) > "/dev/stderr"
	}
	# Subscript is earliest date, subject, actual date, message-id
	# Value is subject, actual date, message-id
	for (i in SubjectDateId) {
		n = split(i, t, SUBSEP)
		if (n != 3) {
			printf("yowsa! n != 3 (n == %d)\n", n) > "/dev/stderr"
			exit 1
		}
		# now have subject, date, message-id in t
		# create index into Text
		Thread[FirstDates[t[1]], i] = SubjectDateId[i]
	}
	n = asorti(Thread, SortedThread)	# Shazzam!
	if (Debug) {
		printf("length(Thread) = %d, length(SortedThread) = %d\n",
			length(Thread), length(SortedThread)) > "/dev/stderr"
	}
	if (n != MessageNum && Duplicates == 0) {
		printf("yowsa! n != MessageNum (n == %d, MessageNum == %d)\n",
			n, MessageNum) > "/dev/stderr"
	#	exit 1
	}
	if (Debug) {
		for (i = 1; i <= n; i++)
			printf("SortedThread[%d] = %s, Thread[SortedThread[%d]] = %d\n",
		 		i, SortedThread[i], i, Thread[SortedThread[i]]) > "DUMP1"
		close("DUMP1")
		if (Debug ~ /exit/)
			exit 0
	}
	for (i = 1; i <= MessageNum; i++) {
		k = Thread[SortedThread[i]]
		for (j = 1; j in Header[k]; j++) {
			print Header[k][j]
			if (Thread_summary_file && Header[k][j] ~ /^[Ff]rom: /)
				dump_summary(i, Header[k][j], SortedThread[i])
		}
		print Body[k]
	}
	if (Thread_summary_file != "")
		close(Thread_summary_file)
}

function dump_summary(messagenum, from, thread_info,
					  t, n, subj)
{
	# thread_info is in the form
	# <first date> SUBSEP <subject> SUBSEP <actual date> SUBSEP <message-id>
	sub(/^[Ff]rom:[[:space:]]*/, "", from)
	n = split(thread_info, t, SUBSEP)
	subj = t[2]
	if (subj != Last_summary_subject)
	{
		printf("%-5d \"%-25.25s\" %-33.33s %s\n",
			messagenum,
			subj,
			from,
			strftime("%Y-%m-%d", t[1])) > Thread_summary_file
		Last_summary_subject = subj
	}
}
# compute_date --- pull apart a date string and convert to timestamp

function compute_date(date_rec,		fields, year, month, day,
					hour, min, sec, tzoff, tzmin, timestamp)
{
	split(date_rec, fields, "[:, ]+")
	if (fields[2] ~ /Sun|Mon|Tue|Wed|Thu|Fri|Sat/) {
		if ($6 == "at") {
			# Date: Thu, Apr 26, 2012 at 7:04 AM
			year = fields[5] + 0
			month = Month[fields[3]]
			day = fields[4] + 0
			hour = fields[7] + 0
			if (tolower(fields[9]) == "pm")
				hour += 12
			min = fields[8] + 0
			sec = 0
			tzoff = 0
		} else {
			# Date: Thu, 05 Jan 2006 17:11:26 -0500
			year = fields[5] + 0
			month = Month[fields[4]]
			day = fields[3] + 0
			hour = fields[6] + 0
			min = fields[7] + 0
			sec = fields[8] + 0
			tzoff = fields[9] + 0
		}
	} else {
		# Date: 05 Jan 2006 17:11:26 -0500
		year = fields[4] + 0
		month = Month[fields[3]]
		day = fields[2] + 0
		hour = fields[5] + 0
		min = fields[6] + 0
		sec = fields[7] + 0
		tzoff = fields[8] + 0
	}
	if (tolower(tzoff) == "gmt")
		tzoff = 0
	# tzoff is usually of form -0200 or +0500 but
	# can sometimes be of form +0530, so deal with that.
	tzmin = 0
	if (tzoff !~ /00$/) {
		# there are minutes in the tz offset
		tzmin = substr(tzmin, length(tzmin) - 2) + 0
		if (min - tzmin < 0) {
			min = 60 + (min - tzmin)
			if (--hour < 0) {
				hour = 23
				if (--day == 0) {
					day = 1
					if (--month == 0) {
						month = 1
						year--
					}
				}
			}
		} else
			min -= tzmin
	}
	tzoff = int(tzoff / 100)
	tzoff = -tzoff
	hour += tzoff
	if (hour > 23) {
		hour %= 24
		day++
		if (day > days_in_month(month, year)) {
			day = 1
			month++
			if (month > 12) {
				month = 1
				year++
			}
		}
	}

	# -1 means DST unknown
	timestamp = mktime(sprintf("%d %d %d %d %d %d -1",
				year, month, day, hour, min, sec))

	# timestamps can be 9 or 10 digits.
	# canonicalize them into 11 digits with leading zeros
	return sprintf("%011d", timestamp)
}
# days_in_month --- how many days in the given month

function days_in_month(month, year)
{
	if (month != 2)
		return MonthDays[month]

	if (year % 4 == 0 && year % 400 != 0)
		return 29

	return 28
}
# canonacalize_subject --- trim out "Re:", white space

function canonacalize_subject(subj_line)
{
	subj_line = tolower(subj_line)			# lower case the line
	sub(/^subject: +/, "", subj_line)		# remove "subject:"
	sub(/^((re|sv): *)+/, "", subj_line)	# remove "re:" (sv: for sweden)
	gsub(/\n/, " ", subj_line)				# merge multiple lines
	sub(/[[:space:]]+$/, "", subj_line)		# remove trailing whitespace
	gsub(/[[:space:]]+/, " ", subj_line)	# collapse multiple whitespace

	return subj_line						# return the result
}
