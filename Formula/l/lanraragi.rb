class Lanraragi < Formula
  desc "Web application for archival and reading of manga/doujinshi"
  homepage "https://github.com/Difegue/LANraragi"
  url "https://github.com/Difegue/LANraragi/archive/refs/tags/v.0.9.22.tar.gz"
  sha256 "979b819994fdf4260a19bf276aef407da9c1d9d294bee44fc7a1f600c1ce5696"
  license "MIT"
  head "https://github.com/Difegue/LANraragi.git", branch: "dev"

  bottle do
    sha256 cellar: :any,                 arm64_sequoia: "e6ad4eba79b3e0aae64d01aaeb64fcdfd5bf6b32f899665fb3c78b61e7568a9d"
    sha256 cellar: :any,                 arm64_sonoma:  "a6fc59bb74de453bfca634f0eb8005aa8d6734bfa0f9e07bb54ce12d122ec570"
    sha256 cellar: :any,                 arm64_ventura: "01c666e8b8eb423b602d9aca72ac34367627f1a1b5efacbcb4c96723cbd1ccb8"
    sha256 cellar: :any,                 sonoma:        "b3f00435e72d7ceee48e0191999f50c2e644d003c25490688426bb118600e585"
    sha256 cellar: :any,                 ventura:       "f316475978784dbb9829ed69d81a45f0eb1273bbce78a77c18bea25043215b99"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "c0c201a1a56fc38f517d2e4388dc81571f2f25283ce7a97e6a2677c079085df8"
  end

  depends_on "nettle" => :build
  depends_on "pkg-config" => :build

  depends_on "cpanminus"
  depends_on "ghostscript"
  depends_on "giflib"
  depends_on "imagemagick"
  depends_on "jpeg-turbo"
  depends_on "libarchive"
  depends_on "libpng"
  depends_on "node"
  depends_on "openssl@3"
  depends_on "perl"
  depends_on "redis"
  depends_on "zstd"

  uses_from_macos "libffi"

  on_macos do
    depends_on "libb2"
    depends_on "lz4"
    depends_on "lzo"
  end

  resource "Image::Magick" do
    url "https://cpan.metacpan.org/authors/id/J/JC/JCRISTY/Image-Magick-7.1.1-28.tar.gz"
    sha256 "bc54137346c1d45626e7075015f7d1dae813394af885457499f54878cfc19e0b"
  end

  def install
    ENV.prepend_create_path "PERL5LIB", libexec/"lib/perl5"
    ENV.prepend_path "PERL5LIB", libexec/"lib"
    ENV.append_to_cflags "-I#{Formula["libarchive"].opt_include}"
    ENV["OPENSSL_PREFIX"] = Formula["openssl@3"].opt_prefix

    imagemagick = Formula["imagemagick"]
    resource("Image::Magick").stage do
      inreplace "Makefile.PL" do |s|
        s.gsub! "/usr/local/include/ImageMagick-#{imagemagick.version.major}",
                "#{imagemagick.opt_include}/ImageMagick-#{imagemagick.version.major}"
      end

      system "perl", "Makefile.PL", "INSTALL_BASE=#{libexec}"
      system "make"
      system "make", "install"
    end

    system "cpanm", "Config::AutoConf", "--notest", "-l", libexec
    system "npm", "install", *std_npm_args(prefix: false)
    system "perl", "./tools/install.pl", "install-full"

    prefix.install "README.md"
    (libexec/"lib").install Dir["lib/*"]
    libexec.install "script", "package.json", "public", "templates", "tests", "lrr.conf"
    cd "tools/build/homebrew" do
      bin.install "lanraragi"
      libexec.install "redis.conf"
    end

    return if OS.linux? || Hardware::CPU.intel?

    # FIXME: This installs its own `libarchive`, but we should use our own to begin with.
    #        As a workaround, install symlinks to our `libarchive` instead of the downloaded ones.
    libarchive_install_dir = libexec/"lib/perl5/darwin-thread-multi-2level/auto/share/dist/Alien-Libarchive3/dynamic"
    libarchive_install_dir.children.map(&:unlink)
    ln_sf Formula["libarchive"].opt_lib.children, libarchive_install_dir
  end

  test do
    # Make sure lanraragi writes files to a path allowed by the sandbox
    ENV["LRR_LOG_DIRECTORY"] = ENV["LRR_TEMP_DIRECTORY"] = testpath
    %w[server.pid shinobu.pid minion.pid].each { |file| touch file }

    # Set PERL5LIB as we're not calling the launcher script
    ENV["PERL5LIB"] = libexec/"lib/perl5"

    # This can't have its _user-facing_ functionality tested in the `brew test`
    # environment because it needs Redis. It fails spectacularly tho with some
    # table flip emoji. So let's use those to confirm _some_ functionality.
    output = <<~EOS
      ｷﾀ━━━━━━(ﾟ∀ﾟ)━━━━━━!!!!!
      (╯・_>・）╯︵ ┻━┻
      It appears your Redis database is currently not running.
      The program will cease functioning now.
    EOS
    # Execute through npm to avoid starting a redis-server
    return_value = OS.mac? ? 61 : 111
    assert_match output, shell_output("npm start --prefix #{libexec}", return_value)
  end
end
