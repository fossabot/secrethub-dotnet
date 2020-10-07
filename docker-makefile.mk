SHELL = bash
SWIG_VERSION = 4.0.2
CGO_FILES = Client.a Client.h
CSHARP_FILES = Client.cs SecretHubXGOPINVOKE.cs Secret.cs SecretVersion.cs
SWIG_FILES = secrethub_wrap.c
OUT_FILES = secrethub_wrap.o libSecretHubXGO.so SecretHubXGO.dll
XGO_DIR = ./secrethub-xgo
DEPS = secrethub_wrap.c Client.h
OBJ = secrethub_wrap.o Client.a
OS_VAR = $(shell uname -s | tr A-Z a-z)

lib: client swig compile
	@echo "Library Ready ^-^"

ifeq ($(OS_VAR), Windows_NT)
.PHONY: client
client: $(XGO_DIR)/secrethub_wrapper.go
	@echo "Making the C library from Go files (Windows)..."
	@cd $(XGO_DIR) && GOOS=windows GOARCH=amd64 CGO_ENABLED=1 CC=x86_64-w64-mingw32-gcc go build -o ../Client.a -buildmode=c-archive secrethub_wrapper.go

.PHONY: compile
compile: $(DEPS)
	@echo "Compiling..."
	@x86_64-w64-mingw32-gcc -c -O2 -fpic -o secrethub_wrap.o secrethub_wrap.c
	@x86_64-w64-mingw32-gcc -shared -fPIC $(OBJ) -o SecretHubXGO.dll
else
.PHONY: client
client: $(XGO_DIR)/secrethub_wrapper.go
	@echo "Making the C library from Go files (Linux)..."
	@cd $(XGO_DIR) && go build -o ../Client.a -buildmode=c-archive secrethub_wrapper.go

.PHONY: compile
compile: $(DEPS)
	@echo "Compiling..."
	@gcc -c -O2 -fpic -o secrethub_wrap.o secrethub_wrap.c
	@gcc -shared -fPIC $(OBJ) -o libSecretHubXGO.so
endif

lib-all:
	@make -f docker-makefile.mk OS_VAR=Linux lib --no-print-directory
	@make -f docker-makefile.mk OS_VAR=Windows_NT lib --no-print-directory

.PHONY: swig
swig:
	@echo "Generating swig files..."
	@swig -csharp -namespace SecretHub secrethub.i
#   Empty class generated by swig.
	@rm SecretHubXGO.cs

# Environment variables used in tests
define TEST_ENV_VARS
TEST=secrethub://secrethub/xgo/dotnet/test/test-secret \
OTHER_TEST=secrethub://secrethub/xgo/dotnet/test/other-test-secret \
TEST_MORE_EQUALS=this=has=three=equals
endef
.PHONY: test
test: lib
	@echo "Testing the library..."
	@cp $(CSHARP_FILES) test
	@dotnet publish test/secrethub.csproj -o build --nologo
ifeq (OS_VAR, Windows_NT)
	@mv SecretHubXGO.dll build
else
	@mv libSecretHubXGO.so build
endif
	@$(TEST_ENV_VARS) dotnet test build/secrethub.dll --nologo
	@make -f docker-makefile.mk clean --no-print-directory

.PHONY: nupkg
nupkg: lib-all
	@echo "Making the NuGet Package..."
	@dotnet pack secrethub.csproj -o build --nologo
	@mv build/SecretHub.*.nupkg .
	@chmod 665 *.nupkg
	@make -f docker-makefile.mk clean --no-print-directory
	@echo "NuGet Package Ready ^-^"

.PHONY: clean
clean:
	@rm -f $(CGO_FILES) $(SWIG_FILES) $(OUT_FILES) $(addprefix test/, $(CSHARP_FILES))
	@rm -rf build bin obj test/bin test/obj
