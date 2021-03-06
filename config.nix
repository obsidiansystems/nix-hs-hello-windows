{
  packageOverrides = ps: rec {
    libyaml = ps.libyaml.overrideAttrs (drv: { patches = [ ./libyaml.patch ]; });

    haskell.lib = ps.haskell.lib;
    haskell.compiler = ps.haskell.compiler // {
      myGhc = (ps.haskell.compiler.ghcHEAD.override {
        # override the version, revision and flavour to get a custom ghc.
        version = "8.5.20180313";
        ghcRevision = "d0d02e2887ccdc3563661410c5fdc897fa6ba074";
        ghcSha256 = "0dzv9152p95xzlr6wimyqmhdffcv15kfl5v2ng522qxsg2y4ixlq";
        ghcCrossFlavour = "quick-cross-ncg";
        ghcFlavour = "quick";
      } // ps.lib.optionalAttrs (ps.targetPlatform != ps.hostPlatform) {
        bootPackages = ps.buildPackages.haskell.packages.myGhc;
      }).overrideAttrs (drv: {
        # override the derivation attributes.
        # Specifically to set dontStrip.
        # name = "ghc-8.5.angerman";
        dontStrip = true;
        # patches = map fetchDiff ghcDiffs;
        hardeningDisable = [ "stackprotector" ];
        patches = [ ./ghc-d0d02e28.patch ];
      });
    };

    haskell.packages = ps.haskell.packages // {
      myGhc = ps.haskell.packages.ghcHEAD.override rec {
        ghc = ps.buildPackages.haskell.compiler.myGhc;
        buildHaskellPackages = ps.buildPackages.haskell.packages.myGhc;
        overrides = self: super: {

          # Custom packages.

          dhall-json = self.callPackage ./dhall-json.nix { };
          Cabal = self.callPackage ./cabal-head.nix { };
          hello-world = self.callPackage ./hello-world.nix { };

          # Custom derivation logic
          mkDerivation = drv: super.mkDerivation (drv // {
            setupHaskellDepends = (drv.setupHaskellDepends or []) ++
              ps.lib.optionals (drv.pname != "Cabal") [ buildHaskellPackages.Cabal ]
              ;
            doHaddock = false;
            hyperlinkSource = false;
          } // ps.lib.optionalAttrs (ps.hostPlatform != ps.buildPlatform) {
            enableSharedLibraries = false;
            enableSharedExecutables = false;
            hardeningDisable = [ "stackprotector" ];
            doHaddock = false;
            dontStrip = true;
          });

          # fetch a package candidate from hackage and return the cabal2nix expression.
          hackageCandidate = name: ver: args: self.callCabal2nix name (fetchTarball "https://hackage.haskell.org/package/${name}-${ver}/candidate/${name}-${ver}.tar.gz") args;

              libiserv = with haskell.lib; addExtraLibrary (enableCabalFlag (self.hackageCandidate "libiserv" "8.5" {}) "network") self.network;
              iserv-proxy = self.hackageCandidate "iserv-proxy" "8.5" { libiserv = self.libiserv; };
              # Why is `network` not properly propagated from `libiserv`?
              remote-iserv = with haskell.lib; addExtraLibrary (self.hackageCandidate "remote-iserv" "8.5" { libiserv = self.libiserv; }) self.network;


              zlib = ps.haskell.lib.overrideCabal super.zlib (drv: {
                version = "0.6.2";
                sha256 = "1vbzf0awb6zb456xf48za1kl22018646cfzq4frvxgb9ay97vk0d";
              });

              lens = let l = ps.haskell.lib.overrideCabal super.lens (drv: {
                version = "4.16";
                sha256 = "16wz3s62zmnmis7xs9jahyc7b75090b96ayk98c3gvzmpg7bx54z";
              }); in ps.haskell.lib.appendPatch l ./lens.patch;


              # patches from head.hackage.
              text = ps.haskell.lib.appendPatch super.text ./head.hackage/patches/text-1.2.2.2.patch;
              blaze-builder = ps.haskell.lib.doJailbreak (ps.haskell.lib.appendPatch super.blaze-builder ./head.hackage/patches/blaze-builder-0.4.0.2.patch);
              unordered-containers = ps.haskell.lib.doJailbreak (ps.haskell.lib.appendPatch super.unordered-containers ./head.hackage/patches/unordered-containers-0.2.8.0.patch);
              semigroupoids = ps.haskell.lib.appendPatch super.semigroupoids ./head.hackage/patches/semigroupoids-5.2.1.patch;
              free = ps.haskell.lib.appendPatch (ps.haskell.lib.overrideCabal super.free (drv: { editedCabalFile = null; revision = null; })) ./head.hackage/patches/free-4.12.4.patch;
              x509 = ps.haskell.lib.appendPatch super.x509 ./x509-1.7.2.patch;
              x509-store = ps.haskell.lib.appendPatch super.x509-store ./head.hackage/patches/x509-store-1.6.5.patch;
              #              in let p = ps.haskell.lib.appendPatches l [
              #                #            ./head.hackage/patches/lens-4.15.4.patch
              #                ./lens.patch
              #              ]; in ps.haskell.lib.overrideCabal p (drv: { doVerbose = true; });

              tls = ps.haskell.lib.appendPatch super.tls ./head.hackage/patches/tls-1.4.0.patch;

              # --allow-newer :-(
              # integer-logarithms = ps.haskell.lib.appendPatch super.integer-logarithms ./integer-logarithms.patch;
              async = ps.haskell.lib.appendPatch super.async ./async.patch;
              # bifunctors = ps.haskell.lib.appendPatch super.bifunctors ./bifunctors.patch;
              # unliftio-core = ps.haskell.lib.doJailbreak super.unliftio-core;
              cabal-doctest = ps.haskell.lib.appendPatch super.cabal-doctest ./cabal-doctest.patch;
              # th-abstraction = ps.haskell.lib.appendPatch super.th-abstraction ./th-abstraction.patch;

              #other patches
              system-fileio = ps.haskell.lib.appendPatch super.system-fileio ./system-fileio.patch;
              text-format = ps.haskell.lib.appendPatch super.text-format ./text-format-0.3.1.1.patch;
              x509-system = ps.haskell.lib.appendPatch super.x509-system ./x509-system-1.6.6.patch;
              streaming-commons = ps.haskell.lib.appendPatch super.streaming-commons ./streaming-commons-0.1.19.patch;
              double-conversion = let p2 = (let p = ps.haskell.lib.appendPatch super.double-conversion ./double-conversion.patch;

              in ps.haskell.lib.overrideCabal p (drv: { doVerbose = true; }));
            in ps.haskell.lib.appendConfigureFlag p2 [ "-v0" ];
              StateVar = ps.haskell.lib.appendPatch super.StateVar ./StateVar.patch;

              mtl = ps.haskell.lib.overrideCabal super.mtl (drv: { libraryHaskellDepends = [ self.base self.transformers ]; });

              contravariant = ps.haskell.lib.appendPatch super.contravariant ./contravariant-1.4.1.patch;
              # missing libraries, due to os(mingw32) check not executed in cabal2nix
              http-client = ps.haskell.lib.addBuildDepends super.http-client [ self.safe ]; # self.Win32 ];
              ansi-terminal = ps.haskell.lib.addBuildDepends super.ansi-terminal [ self.base-compat self.containers ]; #self.Win32 ];
              # disable integer-gmp on cryptonite
              cryptonite = ps.haskell.lib.appendConfigureFlag super.cryptonite [ "-f-integer-gmp" ];

              # disable executables where needed
              aeson-pretty = ps.haskell.lib.overrideCabal super.aeson-pretty (drv: { enableSharedExecutables = false; doVerbose = true; });
              yaml = let p = ps.haskell.lib.overrideCabal         super.yaml         (drv: { enableSharedExecutables = false; }); in ps.haskell.lib.dontStrip p;


              # no stripping
              attoparsec = ps.haskell.lib.dontStrip super.attoparsec;
              aeson = ps.haskell.lib.dontStrip super.aeson;

              # Template Haskell
              trifecta = with ps.haskell.lib;
                         if ps.hostPlatform == ps.buildPlatform then super.trifecta else
                         appendBuildFlags (addExtraLibrary (overrideCabal super.trifecta (drv: { buildTools = [ buildHaskellPackages.iserv-proxy ]; doVerbose = true; })) ps.windows.mingw_w64_pthreads )
                           [ "--ghc-option=-fexternal-interpreter"
                             "--ghc-option=-fexternal-interpreter"
                             "--ghc-option=-pgmi"
                             "--ghc-option=${buildHaskellPackages.iserv-proxy}/bin/iserv-proxy"
                             "--ghc-option=-opti"
                             "--ghc-option=10.0.1.22"
                             "--ghc-option=-opti"
                             "--ghc-option=5001"
                             "--ghc-option=-opti"
                             "--ghc-option=-v "
                           ];
        };
      };
    };
  };
}
