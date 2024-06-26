package org.mineap.nndd {
    import flash.data.EncryptedLocalStore;
    import flash.desktop.NativeApplication;
    import flash.desktop.NativeProcess;
    import flash.filesystem.File;
    import flash.system.Capabilities;

    import mx.controls.TextArea;
    import mx.formatters.DateFormatter;

    import org.mineap.nndd.util.LogUtil;

    /**
     * LogManager.as
     * ログ出力用のクラスです。
     *
     * Copyright (c) 2008 MAP - MineApplicationProject. All Rights Reserved.
     *
     * @author shiraminekeisuke
     *
     */
    public class LogManager {

        private var logString: String = "";
        private var textArea: TextArea;
        private var logDir: File;

        private static const logManager: LogManager = new LogManager();

        /**
         *
         * @param textArea
         *
         */
        public function initialize(textArea: TextArea, logDir: File = null): void {
            var df: DateFormatter = new DateFormatter();
            df.formatString = "YYYYMMDDJJNNSS";
            var dateString: String = df.format(new Date());

            this.textArea = textArea;

            var tempStr: String = this.logString;

            this.logString = dateString + ":" + Message.BOOT_TIME_LOG + "\n\tAIRランタイムバージョン:" +
                             NativeApplication.nativeApplication.runtimeVersion + "\n\tFlashPlayerバージョン:" +
                             Capabilities.version + "\n\tデバッガバージョン:" + Capabilities.isDebugger + "\n\tプレイヤータイプ:" +
                             Capabilities.playerType + "\n\tオペレーティングシステム:" + Capabilities.os + "\n\tネイティブプロセスAPIサポート:" +
                             NativeProcess.isSupported + "\n\t暗号化された保存領域のサポート:" + EncryptedLocalStore.isSupported +
                             "\n\t最高レベルIDC:" + Capabilities.maxLevelIDC + "\n" + "\n\tNNDD-5chは以下のライブラリを使用しています。" +
                             "\n\t・NativeApplicationUpdater - Apache License 2.0 ( http://code.google.com/p/nativeapplicationupdater/ )" +
                             "\n\t・airhttpd - MIT License ( http://code.google.com/p/airhttpd/ )" +
                             "\n\t・nicovideo4as - MIT License ( https://github.com/nndd-reboot/nicovideo4as )" +
                             "\n\t・Flashls - Mozilla Public License 2.0 ( http://www.flashls.org/ )" + "\n";

            this.logString += "\n" + tempStr;

            if (logDir != null) {

                var logFile: File = new File(logDir.url + "/nndd.log");
                if (logFile.exists) {
                    if (logFile.size > 1000000) {
                        this.logString += "\nログファイルが1MBを超えていたので削除しました。";
                        logFile.deleteFile();
                    }
                }

                LogUtil.instance.addLog(this.logString, logDir.url + "/nndd.log");
            }

        }

        /**
         * シングルトンパターン
         *
         * @return
         *
         */
        public static function get instance(): LogManager {
            return logManager;
        }

        /**
         * コンストラクタ。
         *
         */
        public function LogManager() {
            if (logManager != null) {
                throw new ArgumentError("LogManagerはインスタンス化できません。");
            }
        }

        /**
         *
         * @param logDir
         *
         */
        public function setLogDir(logDir: File): void {
            this.logDir = logDir;

            var logFile: File = new File(logDir.url + "/nndd.log");
            var isDelete: Boolean = false;
            if (logFile.exists) {
                if (logFile.size > 1000000) {
                    isDelete = true;
                    logFile.moveTo(new File(logDir.url + "/nndd(old).log"), true);
                }
            }

            LogUtil.instance.addLog(this.logString, logFile.url);

        }

        /**
         * ログを追加します。<br>
         * ログは、既存のログの最後に空白行を付加した後に追加されます。
         *
         * @param ログに追加したい文字列。
         *
         */
        public function addLog(log: String): void {
//			trace("log added:"+logString)

            var df: DateFormatter = new DateFormatter();
            df.formatString = "YYYYMMDDJJNNSS";
            var dateString: String = df.format(new Date());

            log = log.replace("\n", "\n\t");

            var str: String = dateString + ":\t" + log;

            this.logString = this.logString + "\n" + str;

            showLog(this.textArea);

            if (this.logDir != null) {
                LogUtil.instance.addLog("\n\n" + dateString + ":" + log, this.logDir.url + "/nndd.log");
            }
        }

        /**
         * 現在のログ文字列を返します。
         *
         * @return 起動から現在までのログ文字列。
         */
        public function getLog(): String {
            return new String(logString);
        }

        /**
         * ログをTextAreaに出力します。
         */
        public function showLog(textArea: TextArea): void {
            if (textArea != null) {
                textArea.text = logString;
            }
        }

    }
}