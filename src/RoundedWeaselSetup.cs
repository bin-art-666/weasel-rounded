using System;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Diagnostics;
using System.Drawing;
using System.Threading.Tasks;
using System.Windows.Forms;

[assembly: AssemblyTitle("小狼毫 · 通透圆角版安装程序")]
[assembly: AssemblyProduct("小狼毫 · 通透圆角版")]
[assembly: AssemblyVersion("1.0.0.0")]
class SetupForm : Form {
    Label status;
    Button install;
    ProgressBar progress;
    string extracted;
    bool running;
    public SetupForm() {
        Text = "小狼毫 · 通透圆角版";
        ClientSize = new Size(580, 370);
        Font = new Font("Microsoft YaHei UI", 10);
        BackColor = Color.FromArgb(248, 249, 251);
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        Label title = new Label { Text = "小狼毫 · 通透圆角版", Font = new Font(Font.FontFamily, 20, FontStyle.Bold), AutoSize = true, Location = new Point(30, 28) };
        Controls.Add(title);
        Controls.Add(new Label { Text = "雾凇全拼  ·  横排 9 个候选词\n\n通透背景、大圆角、蓝色选中项\n随系统切换深浅色，同一套外观，无其他主题选项。\n\n离线安装；已有配置自动备份，个人学习词库保留。", AutoSize = true, Location = new Point(32, 88) });
        status = new Label { Text = "点击安装即可完成配置。首次安装需要管理员授权。", AutoSize = false, Size = new Size(510, 42), Location = new Point(32, 240) };
        Controls.Add(status);
        progress = new ProgressBar { Location = new Point(32, 290), Size = new Size(350, 16), Visible = false, Style = ProgressBarStyle.Marquee };
        Controls.Add(progress);
        install = new Button { Text = "安装", Location = new Point(420, 285), Size = new Size(125, 40), BackColor = Color.FromArgb(0, 122, 255), ForeColor = Color.White, FlatStyle = FlatStyle.Flat };
        Controls.Add(install);
        install.Click += async delegate { await Install(); };
        FormClosing += delegate(object sender, FormClosingEventArgs e) { if (running) e.Cancel = true; };
    }
    public static string Extract(string destination) {
        Directory.CreateDirectory(destination);
        using (Stream resource = Assembly.GetExecutingAssembly().GetManifestResourceStream("payload.zip"))
        using (ZipArchive zip = new ZipArchive(resource, ZipArchiveMode.Read)) {
            string prefix = Path.GetFullPath(destination).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
            foreach (ZipArchiveEntry entry in zip.Entries) {
                string path = Path.GetFullPath(Path.Combine(destination, entry.FullName));
                if (!path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase)) throw new IOException("Invalid archive path");
                if (String.IsNullOrEmpty(entry.Name)) { Directory.CreateDirectory(path); continue; }
                Directory.CreateDirectory(Path.GetDirectoryName(path));
                entry.ExtractToFile(path, false);
            }
        }
        return destination;
    }
    public static Process RunScript(string directory, string options) {
        string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe");
        ProcessStartInfo info = new ProcessStartInfo(powershell, "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"" + Path.Combine(directory, "install.ps1") + "\" " + options);
        info.UseShellExecute = false;
        info.CreateNoWindow = true;
        // Avoid inheriting PowerShell 7 module paths from a parent process.
        info.EnvironmentVariables["PSModulePath"] = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\Modules") + ";" + Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"WindowsPowerShell\Modules");
        return Process.Start(info);
    }
    async Task Install() {
        if (install.Text == "关闭") { Close(); return; }
        running = true; install.Enabled = false; progress.Visible = true;
        var timer = new System.Windows.Forms.Timer { Interval = 400 };
        timer.Tick += delegate {
            try { if (extracted != null && File.Exists(Path.Combine(extracted, "status.txt"))) status.Text = File.ReadAllText(Path.Combine(extracted, "status.txt")); } catch (IOException) { }
        };
        timer.Start();
        try {
            status.Text = "正在解压离线安装文件…";
            int code = await Task.Run(() => {
                extracted = Extract(Path.Combine(Path.GetTempPath(), "RoundedWeasel-" + Guid.NewGuid().ToString("N")));
                using (Process p = RunScript(extracted, "")) { p.WaitForExit(); return p.ExitCode; }
            });
            timer.Stop();
            if (code != 0) throw new Exception(File.Exists(Path.Combine(extracted, "status.txt")) ? File.ReadAllText(Path.Combine(extracted, "status.txt")) : "安装未完成。");
            status.Text = "安装完成。按 Win＋空格切换到“小狼毫”即可使用。";
        } catch (Exception e) {
            timer.Stop(); status.Text = "安装未完成。";
            MessageBox.Show(e.Message + "\n\n日志目录：" + extracted, Text, MessageBoxButtons.OK, MessageBoxIcon.Warning);
        } finally { timer.Dispose(); running = false; progress.Visible = false; install.Enabled = true; install.Text = "关闭"; }
    }
    [STAThread] static int Main(string[] args) {
        if (args.Length == 2 && args[0] == "--preview") {
            Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
            using (SetupForm form = new SetupForm()) {
                form.ShowInTaskbar = false; form.Opacity = 0;
                form.StartPosition = FormStartPosition.Manual; form.Location = new Point(-30000, -30000);
                form.Show(); Application.DoEvents();
                using (Bitmap bitmap = new Bitmap(form.Width, form.Height)) { form.DrawToBitmap(bitmap, new Rectangle(0, 0, form.Width, form.Height)); bitmap.Save(args[1]); }
            }
            return 0;
        }
        if (args.Length == 2 && (args[0] == "--verify" || args[0] == "--test-config")) {
            try {
                string dir = Extract(Path.GetFullPath(args[1]));
                string options = args[0] == "--verify" ? "-ValidateOnly" : "-TestTarget \"" + Path.Combine(dir, "simulated-user", "Rime") + "\"";
                using (Process p = RunScript(dir, options)) { p.WaitForExit(); return p.ExitCode; }
            } catch (Exception e) { File.WriteAllText(Path.Combine(args[1], "verification-error.txt"), e.ToString()); return 1; }
        }
        Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false); Application.Run(new SetupForm()); return 0;
    }
}
