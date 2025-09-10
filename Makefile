# This file is licensed under the terms of the MIT License
#
# Copyright (c) 2025 Pavel Tsayukov p.tsayukov@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# ============================================================================ #
# This is a multi-platform Makefile for Golang projects, trying to support both
# Unix-like and Windows operating systems.
#
# It is very much inspired by the Makefile made by Alex Edwards. Check that out:
#  - https://www.alexedwards.net/blog/a-time-saving-makefile-for-your-go-projects
#  - https://gist.github.com/alexedwards/3b40775846535d0014ab1ff477e4a568
#
#                    HOW TO WRITE DOCUMENTATION FOR TARGETS
#
# Every comment line that starts with two '#' is parsed by the 'help' target
# as part of the help message:
#  - use '##:' to output an empty line;
#  - use '##<target>:<description>' for a single-line description;
#  - use '##<target>:<description>' with the following '##:<description>',
#    each on the next line, for a multiline description.
#
# Whitespaces between '##', '<target>', ':', and '<description>' do not matter.
#
# A standalone '##:<description>' with the surrounding '##:' at the top
# and bottom can be used to write a header, e.g., 'Variables', 'Build', etc.
#
#                          OPERATING SYSTEM DETECTION
#
# To detect the operating system:
#
# 1. Check whether the environment variable PATH contains the path separator:
#  - in Windows:
    override __semicolon__ := ;
#  - in a Unix-like operating system:
    override __colon__     := :
# Unlikely, but the PATH might contain only one element or a path with
# a semicolon in a Unix-like operating system. It can also be passed
# via the command line to prepend it with the specific user path.
#
# 2. Check the environment variable OS that holds the string 'Windows_NT'
# on the Windows NT family. However, the OS variable can be overwritten.
#
# 3. Call the `uname` command to get the name of the current operating system.
    override __sh_uname_or_unknown__ := sh -c 'uname 2>/dev/null || echo Unknown'
# Transform the Cygwin/MSYS verbose output of `uname` to 'Cygwin'/'MSYS'.
# See: https://stackoverflow.com/a/52062069/10537247
    override __shorten_os_name__ = \
        $(patsubst CYGWIN%,Cygwin,\
            $(patsubst MSYS%,MSYS,\
                $(patsubst MINGW%,MSYS,\
                    $1\
                )\
            )\
        )
#
# Nevertheless, it is unlikely that these pitfalls will occur in most cases.
# Otherwise, pass the OS variable into the `make` call to specify the current
# operating system:
#   make OS=<operating system name> [...]
#
    ifeq ($(origin OS),command line)
        override __OS__ := $(OS)
    else ifeq ($(OS),Windows_NT)
        # Distinguish between native Windows and Cygwin/MSYS.
        ifneq (,$(findstring $(__semicolon__),$(PATH))) # if semicolon is in PATH
            override __OS__ := Windows
        else
            override __OS__ := $(call __shorten_os_name__,$(shell $(__sh_uname_or_unknown__)))
        endif
    else
        override __OS__ := $(shell $(__sh_uname_or_unknown__))
    endif
#
# Use the __OS__ variable to match the detected operating system against
# Windows, Linux, Darwin, etc.
#
#                                 CONFIGURATION
#
# Explicitly say what the target is default; change it as necessary.
    .DEFAULT_GOAL := help
#
# Choosing the appropriate shell, path separator, and list separator.
    ifeq ($(__OS__),Unknown)
        $(error unknown operating system)
    else ifeq ($(__OS__),Windows)
        SHELL := pwsh.exe
        override __PATH_SEP__ := \\
        override __LIST_SEP__ := $(__semicolon__)
    else
        SHELL := /bin/sh
        override __PATH_SEP__ := /
        override __LIST_SEP__ := $(__colon__)
    endif
#
# The project root containing the Makefile as an absolute path.
    override __PROJECT_ROOT__ := $(subst /,$(__PATH_SEP__),$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
#
#                                     TIPS
#
# 1. To split a PowerShell command line over multiple lines use a comment block
# with a backslash inside:
#   do things <#\
#   #> do other things
#
# 2. Colorful output:
#   .PHONY: target
#   target:
#   	@ $(call __go__,Running $@...)
#   	@ $(call __ok__,Running $@ - done)
#   	@ $(call __warn__,Running $@ - warning)
#   	@ $(call __err__,Running $@ - failed)
#
    ifeq ($(__OS__),Windows)
        override __RED__    := Red
        override __GREEN__  := Green
        override __BLUE__   := Blue
        override __YELLOW__ := Yellow
        override __color_text__ = Write-Host "$2" -ForegroundColor $1 -NoNewline
    else
        override __RED__    := \\033[0;31m
        override __GREEN__  := \\033[0;32m
        override __BLUE__   := \\033[0;34m
        override __YELLOW__ := \\033[1;33m
        override __color_text__ = printf "%b%s%b" "$1" "$2" "\033[0m"
    endif

    override __go__   = $(call __color_text__,$(__BLUE__),> ) && echo "$1"
    override __ok__   = $(call __color_text__,$(__GREEN__),v ) && echo "$1"
    override __warn__ = $(call __color_text__,$(__YELLOW__),!! ) && echo "$1"
    override __err__  = $(call __color_text__,$(__RED__),x ) && echo "$1"
#
# 3. Logging:
#
#   .PHONY: do
#   do:
#   	@ $(call __run_with_logging__,Do something,\
#           echo "The did is done" \
#       )
#
    ifeq ($(__OS__),Windows)
        override __run_with_logging__ = \
            $(call __go__,$1...); $2; if ($$?) { \
                $(call __ok__,$1 - done) \
            } else { \
                $(call __err__,$1 - failed); \
                exit 1 \
            }
    else
        override __run_with_logging__ = \
            $(call __go__,$1...); \
            $2; if [ $$? = 0 ]; \
            then $(call __ok__,$1 - done); \
	        else $(call __err__,$1 - failed) \
	             && exit 1; \
	        fi
    endif
# ============================================================================ #

# The blank line below is necessary to get the same help message on different
# operating systems.
##:
## help: print this help message and exit
.PHONY: help
help:
	@ $(info )
	@ $(info :: Go Makefile)
	@ $(info :: OS: $(__OS__))
	@ $(info :: SHELL: $(SHELL))
	@ $(info )
ifeq ($(__OS__),Windows)
	@ Write-Host "Targets:" -NoNewline
    # Hack: replace two '#' with the NULL character to force ConvertFrom-Csv
    # to print empty lines.
	@ (Get-Content $(MAKEFILE_LIST)) -match "^##" -replace "^##","$$([char]0x0)" <#\
 #> | ConvertFrom-Csv -Delimiter ":" -Header Target,Description <#\
 #> | Format-Table <#\
 #>     -AutoSize -HideTableHeaders <#\
 #>     -Property @{Expression=" "},Target,@{Expression=" "},Description
else
	@ echo 'Targets:'
	@ sed --quiet 's/^##//p' $(MAKEFILE_LIST) \
	| sed --expression='s/[ \t]*:[ \t]*/:/' \
    | column --table --separator ':' \
    | sed --expression='s/^/ /' \
    && echo
endif

# ============================================================================ #
##:
##:                                 Variables
##:
# These variables can be changed here directly by editing this file
# or by passing them into the `make` call:
#   make <variable_1>=<value_1> <variable_2>=<value_2> [...]
#
# To generate a target that prints the value of a variable by default,
# use the list below and append it with the variable name:
#   override __variables__ += <variable name>
    override __variables__ :=
#
# If necessary, change the template below.
define __make_variable_getter__
.PHONY: $1
$1:
	@ echo "$($1)"
endef
# ============================================================================ #

## BINARY_DIR: get the directory with binaries
BINARY_DIR := bin
override __variables__ += BINARY_DIR

## GOBIN: get the absolute path where the `go install` command installs binaries;
##      : GOBIN will be exported to child processes and prepended to PATH
export GOBIN ?= $(__PROJECT_ROOT__)$(BINARY_DIR)
export PATH  := $(GOBIN)$(__LIST_SEP__)$(PATH)
override __variables__ += GOBIN

## TARGET_OS: get the target's operation system
TARGET_OS := linux
override __variables__ += TARGET_OS

## TARGET_ARCH: get the target's architecture
TARGET_ARCH := amd64
override __variables__ += TARGET_ARCH

# Generate variable getters for all the variables in the last __variables__.
$(foreach var,$(__variables__), \
    $(eval \
        $(call __make_variable_getter__,$(var)) \
    ) \
)

# ============================================================================ #
#                                    Helpers
# ============================================================================ #

# __choice_or_err__ prompts the user to choose between two options:
# the second one always terminates the 'make' execution with the given error.
#  $1: a prompt prefix
#  $2: a first option
#  $3: a second option
#  $4: a error message
ifeq ($(__OS__),Windows)
    override __choice_or_err__ = \
        if ((Read-Host -Prompt "$1 [$2/$3]") -cne "$2") { \
            $(call __err__,$4); \
            exit 1 \
        }
else
	override __choice_or_err__ = \
	    read -r -p '$1 [$2/$3] ' answer && [ $${answer:-$3} = '$2' ] || ( \
            $(call __err__,$4) \
            && exit 1 \
        )
endif

# __empty_or_err__ runs the given command and terminates the 'make' execution
# with the given error if the command output is not empty.
#  $1: a command
#  $2: a error message
ifeq ($(__OS__),Windows)
    override __empty_or_err__ = \
        if (![string]::IsNullOrEmpty("$(shell $1)")) { \
            $(call __err__,$2); \
            exit 1 \
        }
else
    override __empty_or_err__ = \
        test -z '$(shell $1)' || ( \
            $(call __err__,$2) \
            && exit 1 \
        )
endif

.PHONY: confirm
confirm:
	@ $(call __choice_or_err__,Are you sure?,y,N,The choice is not confirmed. Abort!)

.PHONY: git/no-dirty
git/no-dirty:
	@ $(call __empty_or_err__,git status --porcelain,There are untracked/unstaged/uncommitted changes!)

.PHONY: create/binary_dir
create/binary_dir:
ifeq ($(__OS__),Windows)
	@ [void](New-Item "$(BINARY_DIR)" -ItemType Directory -Force)
else
	@ mkdir -p "$(BINARY_DIR)"
endif

# ============================================================================ #
##:
##:                                   Build
##:
# ============================================================================ #

## mod/download: download modules to local cache
.PHONY: mod/download
mod/download:
	@ $(call __run_with_logging__,Downloading modules to local cache,\
        go mod download -x \
    )

## mod/tidy-diff: check missing and unused modules without modifying
##              : the `go.mod` and `go.sum` files
.PHONY: mod/tidy-diff
mod/tidy-diff:
	@ $(call __go__,$(__mod_tidy_diff_log__)...)
	@ go mod tidy -diff
	@ $(call __ok__,$(__mod_tidy_diff_log__) - done)

override __mod_tidy_diff_log__ := Checking missing and unused modules

## mod/tidy: add missing and remove unused modules
.PHONY: mod/tidy
mod/tidy:
	@ $(call __go__,$(__mod_tidy_log__)...)
	@ go mod tidy -v
	@ $(call __ok__,$(__mod_tidy_log__) - done)

override __mod_tidy_log__ := Adding missing and remove unused modules

## clean: remove files from the binary directory
.PHONY: clean
clean:
	@ $(call __go__,$(__clean_log__)...)
ifeq ($(__OS__),Windows)
	@ if (Test-Path "$(BINARY_DIR)" -PathType Container) { <#\
 #>     Remove-Item "$(BINARY_DIR)\*" -Recurse -Force <#\
 #> }
else
	@ rm -rf $(BINARY_DIR)/*
endif
	@ $(call __ok__,$(__clean_log__) - done)

override __clean_log__ := Cleaning $(BINARY_DIR)

# ============================================================================ #
##:
##:                              Quality control
##:
# ============================================================================ #

## mod/verify: verify that dependencies have expected content
.PHONY: mod/verify
mod/verify:
	@ $(call __go__,$(__mod_verify_log__)...)
	@ go mod verify
	@ $(call __ok__,$(__mod_verify_log__) - done)

override __mod_verify_log__ := Verifying dependencies

## fmt/no-dirty: check package sources whose formatting differs from gofmt
.PHONY: fmt/no-dirty
fmt/no-dirty:
	@ $(call __empty_or_err__,gofmt -d .,Package sources is unformatted)

## fmt: gofmt (reformat) package sources
.PHONY: fmt
fmt:
	@ $(call __go__,$(__fmt_log__)...)
	@ go fmt ./...
	@ $(call __ok__,$(__fmt_log__) - done)

override __fmt_log__ := Reformatting package sources

## vet: report likely mistakes in packages
.PHONY: vet
vet:
	@ $(call __go__,$(__vet_log__)...)
	@ go vet ./...
	@ $(call __ok__,$(__vet_log__) - done)

override __vet_log__ := Running go vet

## golangci-lint: a fast linters runner for Go
.PHONY: golangci-lint
golangci-lint:
	@ $(call __go__,$(__golangci_lint_log__)...)
	@ golangci-lint run ./...
	@ $(call __ok__,$(__golangci_lint_log__) - done)

override __golangci_lint_log__ := Running golangci-lint
