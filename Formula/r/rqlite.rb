class Rqlite < Formula
  desc "Lightweight, distributed relational database built on SQLite"
  homepage "https://www.rqlite.io/"
  url "https://github.com/rqlite/rqlite/archive/refs/tags/v8.24.10.tar.gz"
  sha256 "228511bc7cd2e3b1b40630b4f664c9b3ac27762a3cda77ae92859e694a29e66c"
  license "MIT"
  head "https://github.com/rqlite/rqlite.git", branch: "master"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_sonoma:   "bdb035295bf66903d93bb7428ab86d6f08a92de4033835584c3201736e63e56c"
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "13bb8d80eeb5bf438a7d59dbd6cd5a0573bf204cc2fecd576ad4f62e2ae4a8a4"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "8132dcedabd33f3441f731e75ca9537580a99d6ea605228dbb4a3ca32498ea11"
    sha256 cellar: :any_skip_relocation, sonoma:         "24f1743153f50057dfc563322a5481874590f94be73712bde1b3294a42310ab0"
    sha256 cellar: :any_skip_relocation, ventura:        "5393d84c2df83eece33a13bc47821dd64c09f1677a01862ccd31895cd5013074"
    sha256 cellar: :any_skip_relocation, monterey:       "78862d5474a7001215b29a6e71d500c7aad8a50d653696f3891c2dfa4f13f2ea"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "da9421ca44ab52dc8ec8748a0d10fb3035820caf92b6b50fe5bb5198b176493b"
  end

  depends_on "go" => :build

  def install
    %w[rqbench rqlite rqlited].each do |cmd|
      system "go", "build", *std_go_args(ldflags: "-s -w"), "-o", bin/cmd, "./cmd/#{cmd}"
    end
  end

  test do
    port = free_port
    fork do
      exec bin/"rqlited", "-http-addr", "localhost:#{port}",
                          "-raft-addr", "localhost:#{free_port}",
                          testpath
    end
    sleep 5

    (testpath/"test.sql").write <<~EOS
      CREATE TABLE foo (id INTEGER NOT NULL PRIMARY KEY, name TEXT)
      .schema
      quit
    EOS
    output = shell_output("#{bin}/rqlite -p #{port} < test.sql")
    assert_match "foo", output

    output = shell_output("#{bin}/rqbench -a localhost:#{port} 'SELECT 1'")
    assert_match "Statements/sec", output
  end
end
