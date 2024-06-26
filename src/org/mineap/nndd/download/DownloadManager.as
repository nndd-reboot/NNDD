package org.mineap.nndd.download {
    import flash.errors.IOError;
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.IOErrorEvent;
    import flash.events.ProgressEvent;
    import flash.events.TimerEvent;
    import flash.filesystem.File;
    import flash.utils.Timer;

    import mx.collections.ArrayCollection;
    import mx.containers.Canvas;
    import mx.controls.Alert;
    import mx.core.FlexGlobals;
    import mx.events.CloseEvent;
    import mx.formatters.NumberFormatter;

    import org.mineap.nndd.FileIO;
    import org.mineap.nndd.LogManager;
    import org.mineap.nndd.Message;
    import org.mineap.nndd.NNDDDownloader;
    import org.mineap.nndd.downloadedList.DownloadedListManager;
    import org.mineap.nndd.library.ILibraryManager;
    import org.mineap.nndd.library.LibraryManagerBuilder;
    import org.mineap.nndd.library.LocalVideoInfoLoader;
    import org.mineap.nndd.model.DownloadQueueItem;
    import org.mineap.nndd.model.NNDDVideo;
    import org.mineap.nndd.util.LibraryUtil;
    import org.mineap.nndd.util.PathMaker;
    import org.mineap.util.config.ConfigManager;

    /**
     * DownloadManager.as
     *
     * Copyright (c) 2009 MAP - MineApplicationProject. All Rights Reserved.
     *
     * @author shiraminekeisuke
     *
     */
    public class DownloadManager extends EventDispatcher {
        public static const DEFAULT_MAX_DLLIST_COUNT: int = 100;


        public var downloadProvider: ArrayCollection;
        public var myListProvider: ArrayCollection;
        public var searchProvider: ArrayCollection;
        public var downloadedListManager: DownloadedListManager;
        public var rankingProvider: ArrayCollection;
        public var libraryManager: ILibraryManager;
        private var logManager: LogManager;
        private var _nnddDownloader: NNDDDownloader;
        private var mailaddress: String;
        private var password: String;

        private var isCancel: Boolean;
        private var queueId: String;
        private var queueVideoName: String;

        private var isDownloading: Boolean = false;

        private var isRetry: Boolean = false;
        private var retryCount: int = 0;
        private var _retryMaxCount: int = 2;

        private var timer: Timer = null;

        private var canvasQueue: Canvas = null;

        private var downloadItemMap: Object = new Object();

        public var isContactTheUser: Boolean = false;

        public var isAlwaysEconomy: Boolean = false;

        public var isAppendComment: Boolean = false;

        public var isUseDownloadDir: Boolean = false;

        public var isSkipEconomy: Boolean = false;

        private var lastStatusUpdateTime: Date = new Date();

        private var loadedBytes: Number = 0.0;

        private var _maxDlListCount: int = DEFAULT_MAX_DLLIST_COUNT;

        /**
         *
         * @param downloadProvider
         * @param downloadedListManager
         * @param mailaddress
         * @param password
         * @param canvasQueue
         * @param rankingProvider
         * @param searchProvider
         * @param myListProvider
         * @param logManager
         *
         */
        public function DownloadManager(downloadProvider: ArrayCollection,
                                        downloadedListManager: DownloadedListManager,
                                        mailaddress: String,
                                        password: String,
                                        canvasQueue: Canvas,
                                        rankingProvider: ArrayCollection,
                                        searchProvider: ArrayCollection,
                                        myListProvider: ArrayCollection,
                                        logManager: LogManager
        ) {
            this.downloadProvider = downloadProvider;
            this.myListProvider = myListProvider;
            this.searchProvider = searchProvider;
            this.downloadedListManager = downloadedListManager;
            this.libraryManager = LibraryManagerBuilder.instance.libraryManager;
            this.mailaddress = mailaddress;
            this.password = password;
            this.canvasQueue = canvasQueue;
            this.rankingProvider = rankingProvider;
            this.logManager = logManager;

            this.loadDownloadList();
        }

        /**
         * メールアドレスとパスワードを設定します。
         * @param mailAddress
         * @param password
         *
         */
        public function setMailAndPass(mailAddress: String = "", password: String = ""): void {
            this.mailaddress = mailAddress;
            this.password = password;
        }

        /**
         * 動画をキューに追加します。
         * @param video 動画オブジェクト
         * @paran isStart ダウンロードを開始するかどうか
         * @return
         *
         */
        public function add(video: NNDDVideo, isStart: Boolean): Boolean {

            if (downloadProvider.length >= this.maxDlListCount) {
                return false;
            }

            var item: DownloadQueueItem = new DownloadQueueItem(video, new Date());

            var url: String = "http://www.nicovideo.jp/watch/" + PathMaker.getVideoID(video.getDecodeUrl());

            downloadProvider.addItem({
                                         col_preview: video.thumbUrl,
                                         col_videoName: video.videoName,
                                         col_videoUrl: url,
                                         col_status: "待機中",
                                         col_id: item.getDownloadID(),
                                         col_statusType: DownloadStatusType.NOT_START
                                     });

            showCountRest();

            if (!isDownloading && isStart) {
                // "待機中"のものを探してダウンロード開始
                // ユーザ操作のDL開始なのでスキップしたのもやる
                next(true);
            }

            return true;
        }

        /**
         * DLリストの長さを返します。
         * @return
         *
         */
        public function get listLength(): int {
            return downloadProvider.length;
        }

        /**
         * DLリスト内の項目のうち、DL済みの件数を返します。
         * @return
         *
         */
        public function get downloadedItem(): int {
            var count: int = 0;
            for (var i: int = 0; downloadProvider.length > i; i++) {
                if (downloadProvider[i].col_statusType == DownloadStatusType.COMPLETE) {
                    ++count;
                }
            }
            return count;
        }

        /**
         * 次のダウンロードを開始します。
         * キューを上から探索し、ダウンロード済みでないものを見つけたらダウンロードを開始します。
         *
         * @param ignoreSkipFlag キューを上から探索した際、スキップフラグがtrueに設定されている動画のDLを行うかどうかです。
         *
         */
        public function next(ignoreSkipFlag: Boolean): void {
            isCancel = false;

            if (mailaddress != "" && password != "") {
                if (isDownloading == false) {

                    if (ignoreSkipFlag) {
                        // Complete以外をNotstartに上書き
                        stop();
                    }

                    for (var i: int = 0; downloadProvider.length > i; i++) {

                        var type: Object = downloadProvider[i].col_statusType;
                        if (DownloadStatusType.RETRY_OVER == type || DownloadStatusType.ECONOMY_SKIP == type) {
                            if (ignoreSkipFlag) {
                                // スキップしない
                            } else {
                                // スキップフラグがtrueなら次へ
                                continue;
                            }
                        }
                        if (downloadProvider[i].col_statusType == DownloadStatusType.DOWNLOADEING) {
                            // ココにDownloadingがあるのはおかしい。NOT_STARTで上書き
                            downloadProvider[i].col_statusType = DownloadStatusType.NOT_START;
                        }

                        // DL処理開始
                        if (downloadProvider[i].col_statusType == DownloadStatusType.NOT_START ||
                            downloadProvider[i].col_statusType == DownloadStatusType.RETRY_OVER ||
                            downloadProvider[i].col_statusType == DownloadStatusType.ECONOMY_SKIP) {

                            this.queueId = downloadProvider[i].col_id;
                            this.queueVideoName = downloadProvider[i].col_videoName;

                            isDownloading = true;

                            var timerCount: int = 10;
                            if (retryCount > 0) {
                                timerCount = timerCount * (retryCount * 2);
                            }
                            if (retryCount >= retryMaxCount) {
                                // リトライオーバー
                                downloadProvider.setItemAt({
                                                               col_preview: downloadProvider[i].col_preview,
                                                               col_videoName: downloadProvider[i].col_videoName,
                                                               col_videoUrl: downloadProvider[i].col_videoUrl,
                                                               col_status: downloadProvider[i].col_status,
                                                               col_id: downloadProvider[i].col_id,
                                                               col_downloadedPath: downloadProvider[i].col_downloadedPath,
                                                               col_statusType: DownloadStatusType.RETRY_OVER
                                                           }, i);

                                retryCount = 0;
                                isDownloading = false;

                                next(false);
                                return;
                            }

                            if (timer != null) {
                                timer.stop();
                            }

                            var retry: String = "";
                            if (this.isRetry) {
                                retry = "\nリトライしています";
                            }

                            timer = new Timer(1000, timerCount);
                            downloadProvider.setItemAt({
                                                           col_preview: downloadProvider[i].col_preview,
                                                           col_videoName: downloadProvider[i].col_videoName,
                                                           col_videoUrl: downloadProvider[i].col_videoUrl,
                                                           col_status: timerCount + "秒後にダウンロード開始" + retry,
                                                           col_id: downloadProvider[i].col_id,
                                                           col_downloadedPath: downloadProvider[i].col_downloadedPath,
                                                           col_statusType: DownloadStatusType.NOT_START
                                                       }, i);
                            timer.addEventListener(TimerEvent.TIMER, function (event: TimerEvent): void {
                                timerCount--;
                                var index: int = searchQueueIndexByQueueId(queueId);
                                downloadProvider.setItemAt({
                                                               col_preview: downloadProvider[i].col_preview,
                                                               col_videoName: downloadProvider[index].col_videoName,
                                                               col_videoUrl: downloadProvider[index].col_videoUrl,
                                                               col_status: timerCount + "秒後にダウンロード開始" + retry,
                                                               col_id: downloadProvider[index].col_id,
                                                               col_downloadedPath: downloadProvider[index].col_downloadedPath,
                                                               col_statusType: DownloadStatusType.NOT_START
                                                           }, index);
                            });
                            timer.addEventListener(TimerEvent.TIMER_COMPLETE, function (event: TimerEvent): void {
                                download(queueId);
                                showCountRest();
                            });
                            timer.start();

                            showCountRest();

                            return;
                        }
                    }
                }
            }
        }

        /**
         * 指定されたIDを持つ動画のダウンロードを開始します
         *
         * @param id
         *
         */
        private function download(id: String): void {

            if (mailaddress != "" && password != "") {

                var index: int = searchQueueIndexByQueueId(id);

                this.loadedBytes = 0;
                this.lastStatusUpdateTime = new Date();

                this.queueVideoName = downloadProvider[index].col_videoName;

                isRetry = false;
                var video: NNDDVideo = libraryManager.isExist(LibraryUtil.getVideoKey(downloadProvider[index].col_videoUrl));
                if (video == null) {
                    video = new NNDDVideo(downloadProvider[index].col_videoUrl, downloadProvider[index].col_videoName);
                }
                this._nnddDownloader = createNNDDDrequestDownload(video);

                //失敗系ハンドラ登録
                this._nnddDownloader.addEventListener(NNDDDownloader.COMMENT_GET_FAIL, getFailListener, false, 0, true);
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.GETFLV_API_ACCESS_FAIL,
                    getFailListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(NNDDDownloader.LOGIN_FAIL, getFailListener, false, 0, true);
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.NICOWARI_GET_FAIL,
                    getFailListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.OWNER_COMMENT_GET_FAIL,
                    getFailListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.THUMB_IMG_GET_FAIL,
                    getFailListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.THUMB_INFO_GET_FAIL,
                    getFailListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(NNDDDownloader.VIDEO_GET_FAIL, getFailListener, false, 0, true);
                this._nnddDownloader.addEventListener(NNDDDownloader.WATCH_FAIL, getFailListener, false, 0, true);

                //成功系ハンドラ登録
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.COMMENT_GET_SUCCESS,
                    getSuccessListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.GETFLV_API_ACCESS_SUCCESS,
                    getSuccessListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(NNDDDownloader.LOGIN_SUCCESS, getSuccessListener, false, 0, true);
                this._nnddDownloader.addEventListener(NNDDDownloader.LOGIN_SKIP, getSuccessListener, false, 0, true);
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.NICOWARI_GET_SUCCESS,
                    getSuccessListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.OWNER_COMMENT_GET_SUCCESS,
                    getSuccessListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.THUMB_IMG_GET_SUCCESS,
                    getSuccessListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.THUMB_INFO_GET_SUCCESS,
                    getSuccessListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.VIDEO_GET_SUCCESS,
                    getSuccessListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(NNDDDownloader.WATCH_SUCCESS, getSuccessListener, false, 0, true);

                this._nnddDownloader.addEventListener(
                    NNDDDownloader.COMMENT_GET_START,
                    getProgressListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.GETFLV_API_ACCESS_START,
                    getProgressListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(NNDDDownloader.LOGIN_START, getProgressListener, false, 0, true);
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.NICOWARI_GET_START,
                    getProgressListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.OWNER_COMMENT_GET_START,
                    getProgressListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.THUMB_IMG_GET_START,
                    getProgressListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.THUMB_INFO_GET_START,
                    getProgressListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.VIDEO_GET_START,
                    getProgressListener,
                    false,
                    0,
                    true
                );
                this._nnddDownloader.addEventListener(NNDDDownloader.WATCH_START, getProgressListener, false, 0, true);

                //プログレスハンドラ登録
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.VIDEO_DOWNLOAD_PROGRESS,
                    downloadProgressHandler,
                    false,
                    0,
                    true
                );

                //完了系ハンドラ登録
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.DOWNLOAD_PROCESS_ECONOMY_MODE_SKIP,
                    downlaodFailListener
                );
                this._nnddDownloader.addEventListener(NNDDDownloader.DOWNLOAD_PROCESS_CANCELD, downlaodFailListener);
                this._nnddDownloader.addEventListener(NNDDDownloader.DOWNLOAD_PROCESS_ERROR, downlaodFailListener);
                this._nnddDownloader.addEventListener(
                    NNDDDownloader.DOWNLOAD_PROCESS_COMPLETE,
                    downloadCompleteListener
                );

                logManager.addLog("***ニコニコ動画へ動画取得のリクエスト***");

                this._nnddDownloader.requestStart(this.mailaddress, this.password);
            }


        }

        /**
         * 進行中のニコ動へのアクセスをキャンセルさせます。
         */
        public function stop(): void {
            retryCount = 0;
            if (isDownloading) {
                isCancel = true;

                var index: int = searchQueueIndexByQueueId(queueId);

                if (index != -1) {
                    if (this._nnddDownloader != null) {
                        this._nnddDownloader.close(true, false);
                        logManager.addLog("ニコニコ動画へのアクセスをキャンセル");
                    }
                    if (timer != null) {
                        timer.stop();
                    }

                    setStatus("待機中\nキャンセルされました", DownloadStatusType.NOT_START, queueVideoName, index);

                    isDownloading = false;
                    showCountRest();
                }
            }

            // 完了以外のステータスを Not_start に更新
            for (var i: int = 0; downloadProvider.length > i; i++) {
                if (DownloadStatusType.COMPLETE == downloadProvider[i].col_statusType) {
                    continue;
                }
                downloadProvider.setItemAt({
                                               col_preview: downloadProvider[i].col_preview,
                                               col_videoName: downloadProvider[i].col_videoName,
                                               col_videoUrl: downloadProvider[i].col_videoUrl,
                                               col_status: downloadProvider[i].col_status,
                                               col_id: downloadProvider[i].col_id,
                                               col_downloadedPath: downloadProvider[i].col_downloadedPath,
                                               col_statusType: DownloadStatusType.NOT_START
                                           }, i);
            }

        }

        /**
         * すべてのダウンロードをキャンセルし、DLリストを空にします。
         *
         */
        public function emptyList(): void {

            Alert.show(
                Message.M_DOWNLOAD_PROCESSING,
                Message.M_MESSAGE,
                Alert.OK | Alert.CANCEL,
                null,
                function (event: CloseEvent): void {
                    if (event.detail == Alert.OK) {
                        stop();
                        downloadItemMap = new Object();
                        downloadProvider.removeAll();
                        showCountRest();
                    }
                },
                null,
                Alert.CANCEL
            );
        }

        /**
         * ダウンロード済みの動画をDLリストから削除します。
         *
         */
        public function removeDownloadedVideo(): void {
            Alert.show(
                Message.M_ALL_DOWNLOADED_VIDEO_DELETE,
                Message.M_MESSAGE,
                Alert.OK | Alert.CANCEL,
                null,
                function (event: CloseEvent): void {
                    if (event.detail == Alert.OK) {

                        var index: int = 0;
                        if (downloadProvider.length > 0) {
                            while (true) {
                                var object: Object = downloadProvider[index];
                                if (DownloadStatusType.COMPLETE == object.col_statusType) {
                                    downloadProvider.removeItemAt(index);
                                } else {
                                    index++;
                                }
                                if (index >= downloadProvider.length) {
                                    break;
                                }
                            }
                        }

                        showCountRest();
                    }
                },
                null,
                Alert.CANCEL
            );
        }

        /**
         * 渡されたインデックスの項目をリストから削除します。
         * @param selectedIndices
         *
         */
        public function deleteSelectedItems(selectedIndices: Array): void {
            selectedIndices.sort(Array.NUMERIC);
            for (var i: int = selectedIndices.length - 1; i >= 0; i--) {
                var index: int = selectedIndices[i];

                var qIndex: int = searchQueueIndexByQueueId(queueId);

                if (index != qIndex || !isDownloading) {

                    delete downloadItemMap[downloadProvider[index].col_id];

                    downloadProvider.removeItemAt(index);

                    qIndex = searchQueueIndexByQueueId(queueId);
                    if (qIndex != -1) {
                        queueVideoName = downloadProvider[qIndex].col_videoName;
                    }
                    showCountRest();

                } else {
                    Alert.show(
                        Message.M_THIS_ITEM_IS_DOWNLOADING,
                        Message.M_MESSAGE,
                        Alert.OK | Alert.CANCEL,
                        null,
                        function (event: CloseEvent): void {
                            if (event.detail == Alert.OK) {

                                delete downloadItemMap[downloadProvider[index].col_id];

                                downloadProvider.removeItemAt(index);
                                if (_nnddDownloader != null) {
                                    _nnddDownloader.close(true, false);
                                }
                                isDownloading = false;
                                if (timer != null) {
                                    timer.stop();
                                }
                                qIndex = searchQueueIndexByQueueId(queueId);
                                if (qIndex != -1) {
                                    queueVideoName = downloadProvider[qIndex].col_videoName;
                                }
                                showCountRest();
                            }
                        },
                        null,
                        Alert.CANCEL
                    );
                }

            }
        }

        /**
         * "待機中"の項目を数えて、タブに反映します。
         *
         * @return 残りの"待機中"の項目数
         */
        public function showCountRest(): int {
            var count: int = 0;
//			if(isDownloading){
//				count++;
//			}
            for (var i: int = 0; i < downloadProvider.length; i++) {
                if (downloadProvider[i].col_statusType == DownloadStatusType.DOWNLOADEING ||
                    downloadProvider[i].col_statusType == DownloadStatusType.NOT_START ||
                    downloadProvider[i].col_statusType == DownloadStatusType.RETRY_OVER) {
                    count++;
                }
            }
            if (canvasQueue != null) {
                if (count != 0) {
                    canvasQueue.label = "DLリスト(" + count + ")";
                } else {
                    canvasQueue.label = "DLリスト";
                }
            }

            saveDownloadList();

            return count;
        }


        /**
         *
         * @param video
         * @return
         *
         */
        public function createNNDDDrequestDownload(video: NNDDVideo): NNDDDownloader {

            var nnddDownloader: NNDDDownloader = new NNDDDownloader();
            var myLibrary: File = libraryManager.libraryDir;
            var defLibrary: File = libraryManager.libraryDir;

            if (isUseDownloadDir) {
                myLibrary = defLibrary = defLibrary.resolvePath("Download");
            }

            try {
                if (video.getDecodeUrl() != null) {
                    myLibrary = new File(video.getDecodeUrl().substr(0, video.getDecodeUrl().lastIndexOf("/")));
                    if (!myLibrary.exists) {
                        myLibrary = defLibrary;
                    }
                }
            } catch (error: Error) {
                myLibrary = defLibrary;
            }
            nnddDownloader.requestDownload(this.mailaddress,
                                           this.password,
                                           PathMaker.getVideoID(video.getDecodeUrl()),
                                           null,
                                           myLibrary,
                                           false,
                                           this.isContactTheUser,
                                           this.isAlwaysEconomy,
                                           this.isAppendComment,
                                           FlexGlobals.topLevelApplication.getSaveCommentMaxCount(),
                                           FlexGlobals.topLevelApplication.getUseOldTypeCommentGet(),
                                           this.isSkipEconomy
            );

            return nnddDownloader;
        }

        /**
         * 引数で渡されたNNDDVideoオブジェクトと同じuriの動画がDLリストに既に追加されていないか調べます。
         * @param video
         * @return
         *
         */
        public function isExists(video: NNDDVideo): Boolean {

            for (var i: int = 0; i < downloadProvider.length; i++) {
                if (downloadProvider[i].col_videoUrl == video.getDecodeUrl()) {
                    return true;
                }
                if (PathMaker.getVideoID(downloadProvider[i].col_videoUrl) ==
                    PathMaker.getVideoID(video.getDecodeUrl())) {
                    return true;
                }
            }

            return false;
        }

        /**
         *
         * @param event
         *
         */
        public function getProgressListener(event: Event): void {
            var status: String = "";
            if (event.type == NNDDDownloader.LOGIN_START) {
                status = "ログイン中...";
            } else if (event.type == NNDDDownloader.WATCH_START) {
                status = "動画ページにアクセス中...";
            } else if (event.type == NNDDDownloader.GETFLV_API_ACCESS_START) {
                status = "動画取得APIにアクセス中...";
            } else if (event.type == NNDDDownloader.COMMENT_GET_START) {
                status = "コメント取得中...";
            } else if (event.type == NNDDDownloader.OWNER_COMMENT_GET_START) {
                status = "投稿者コメント取得中...";
            } else if (event.type == NNDDDownloader.NICOWARI_GET_START) {
                status = "ニコ割取得中...";
            } else if (event.type == NNDDDownloader.THUMB_INFO_GET_START) {
                status = "サムネイル情報取得中...";
            } else if (event.type == NNDDDownloader.THUMB_IMG_GET_START) {
                status = "サムネイル画像取得中...";
            } else if (event.type == NNDDDownloader.VIDEO_GET_START) {
                status = "動画取得中...";
            }

            var newVideoName: String = null;
            if (NNDDDownloader(event.currentTarget).nicoVideoName != null) {
                newVideoName = NNDDDownloader(event.currentTarget).nicoVideoName;
            }

            logManager.addLog(status + ":" + event.type);

            var index: int = searchQueueIndexByQueueId(queueId);

            setStatus("進行中\n" + status, DownloadStatusType.DOWNLOADEING, queueVideoName, index, "", newVideoName);

            if (newVideoName != null) {
                queueVideoName = newVideoName;
            }
        }

        /**
         * 取得成功系リスナー
         * @param event
         *
         */
        public function getSuccessListener(event: Event): void {
            var status: String = "";

            if (event.type == NNDDDownloader.LOGIN_SUCCESS) {
                status = "ログイン成功";
            } else if (event.type == NNDDDownloader.LOGIN_SKIP) {
                status = "ログインしない";
            } else if (event.type == NNDDDownloader.WATCH_SUCCESS) {
                status = "動画ページアクセス成功";
            } else if (event.type == NNDDDownloader.GETFLV_API_ACCESS_SUCCESS) {
                status = "APIアクセス成功";
            } else if (event.type == NNDDDownloader.COMMENT_GET_SUCCESS) {
                status = "コメント取得成功";
            } else if (event.type == NNDDDownloader.OWNER_COMMENT_GET_SUCCESS) {
                status = "投稿者コメント取得成功";
            } else if (event.type == NNDDDownloader.NICOWARI_GET_SUCCESS) {
                status = "ニコ割取得成功";
            } else if (event.type == NNDDDownloader.THUMB_INFO_GET_SUCCESS) {
                status = "サムネイル情報取得成功";
            } else if (event.type == NNDDDownloader.THUMB_IMG_GET_SUCCESS) {
                status = "サムネイル画像取得成功";
            } else if (event.type == NNDDDownloader.VIDEO_GET_SUCCESS) {
                status = "動画取得成功";
            }

            var newVideoName: String = null;
            if (NNDDDownloader(event.currentTarget).nicoVideoName != null) {
                newVideoName = NNDDDownloader(event.currentTarget).nicoVideoName;
            }

            logManager.addLog(status + ":" + event.type);

            var index: int = searchQueueIndexByQueueId(queueId);

            setStatus("進行中\n" + status, DownloadStatusType.DOWNLOADEING, queueVideoName, index, "", newVideoName);

            if (newVideoName != null) {
                queueVideoName = newVideoName;
            }
        }

        /**
         * 取得失敗系リスナー
         * @param event
         *
         */
        public function getFailListener(event: IOErrorEvent): void {
            var status: String = "";
            if (event.type == NNDDDownloader.LOGIN_FAIL) {
                status = "ログイン失敗";
            } else if (event.type == NNDDDownloader.WATCH_FAIL) {
                status = "動画ページアクセス失敗";
            } else if (event.type == NNDDDownloader.GETFLV_API_ACCESS_FAIL) {
                status = "APIアクセス失敗";
            } else if (event.type == NNDDDownloader.COMMENT_GET_FAIL) {
                status = "コメント取得失敗";
            } else if (event.type == NNDDDownloader.OWNER_COMMENT_GET_FAIL) {
                status = "投稿者コメント取得失敗";
            } else if (event.type == NNDDDownloader.NICOWARI_GET_FAIL) {
                status = "ニコ割取得失敗";
            } else if (event.type == NNDDDownloader.THUMB_INFO_GET_FAIL) {
                status = "サムネイル情報取得失敗";
            } else if (event.type == NNDDDownloader.THUMB_IMG_GET_FAIL) {
                status = "サムネイル画像取得失敗";
            } else if (event.type == NNDDDownloader.VIDEO_GET_FAIL) {
                status = "動画取得失敗";
            }

            var newVideoName: String = null;
            if (NNDDDownloader(event.currentTarget).nicoVideoName != null) {
                newVideoName = NNDDDownloader(event.currentTarget).nicoVideoName;
            }

            logManager.addLog(status + ":" + event.type + ":" + event.text);
            var index: int = searchQueueIndexByQueueId(queueId);
            setStatus("進行中\n" + status, DownloadStatusType.DOWNLOADEING, queueVideoName, index, "", newVideoName);

            if (newVideoName != null) {
                queueVideoName = newVideoName;
            }
        }

        /**
         * プログレスイベント用リスナー
         * @param event
         *
         */
        public function downloadProgressHandler(event: ProgressEvent): void {
            if (event.type == NNDDDownloader.VIDEO_DOWNLOAD_PROGRESS) {
                var now: Date = new Date();
                var elapsedMilliSec: Number = now.time - lastStatusUpdateTime.time;

                if (elapsedMilliSec > 100) {
                    var decimalPlace1: NumberFormatter = new NumberFormatter();
                    decimalPlace1.precision = 1;
                    var decimalPlace2: NumberFormatter = new NumberFormatter();
                    decimalPlace2.precision = 2;

                    var size: String = decimalPlace1.format(event.bytesLoaded / 1048576) + "/" + decimalPlace1.format(event.bytesTotal / 1048576) + "MB";
                    var percentage: String = int(event.bytesLoaded * 100 / event.bytesTotal) + "%";
                    var speed: String = "";
                    var remain: String = "";

                    var loadedBytesThisEvent: Number = event.bytesLoaded - this.loadedBytes;

                    if (loadedBytesThisEvent / elapsedMilliSec < 1024) {
                        speed = decimalPlace1.format(loadedBytesThisEvent * 1000 / (elapsedMilliSec * 1024)) + "KB/s";
                    }
                    else {
                        speed = decimalPlace2.format(loadedBytesThisEvent * 1000 / (elapsedMilliSec * 1048576)) + "MB/s";
                    }

                    var remainMinutes: Number = Math.round((event.bytesTotal - event.bytesLoaded) * elapsedMilliSec / (loadedBytesThisEvent * 60000));

                    if (event.bytesLoaded * elapsedMilliSec / loadedBytesThisEvent > 20000) {
                        if (remainMinutes == 0) {
                            remain = "あとちょっと";
                        }
                        else {
                            remain = "あと" + remainMinutes + "分くらい";
                        }
                    }

                    var status: String =
                        "動画をダウンロード中 " + remain + "\n"
                        + percentage + " (" + speed + ")\n"
                        + size;

                    var index: int = searchQueueIndexByQueueId(queueId);

                    setStatus(status, DownloadStatusType.DOWNLOADEING, queueVideoName, index);
                    this.lastStatusUpdateTime = now;
                    this.loadedBytes = event.bytesLoaded;
                }
            }
        }

        /**
         * ダウンロード完了リスナー
         * @param event
         *
         */
        public function downloadCompleteListener(event: Event): void {

            /** ここから今までのAccess2Nicoの処理 **/

            var nnddVideo: NNDDVideo = (event.target as NNDDDownloader).downloadedVideo;
            nnddVideo.modificationDate = new Date();
            //ライブラリに同じ物があれば削除
            var videoId: String = LibraryUtil.getVideoKey(nnddVideo.getDecodeUrl());
            var oldVideo: NNDDVideo = null;
            if (videoId != null) {
                oldVideo = libraryManager.remove(videoId, false);
                if (oldVideo != null && nnddVideo.getDecodeUrl() != oldVideo.getDecodeUrl()) {
                    nnddVideo.creationDate = oldVideo.creationDate;
                    if (nnddVideo.creationDate != null) {
                        nnddVideo.creationDate = nnddVideo.modificationDate;
                    }

                    try {
                        //既にDL済のファイルが存在するが、エコノミーモードだった等の理由でファイル名（拡張子）が違う。ファイルが２個できるのを防ぐため、古い方を削除。
                        var oldFile: File = new File(oldVideo.uri);
                        if (oldFile.exists) {
                            oldFile.deleteFile();
                        }
                    } catch (error: Error) {
                        logManager.addLog("ダウンロード済みの古いファイルを削除しようとしましたが、失敗しました。:" + oldVideo.getDecodeUrl() +
                                          "\nError:" + error.getStackTrace());
                    }
                } else {
                    nnddVideo.creationDate = new Date();
                }
            } else {
                nnddVideo.creationDate = nnddVideo.modificationDate;
            }

            //タグ情報を読み込んでライブラリに反映
            var video: NNDDVideo = new LocalVideoInfoLoader().loadInfo(nnddVideo.getDecodeUrl());
            var localThumbImgPath: String = (event.currentTarget as NNDDDownloader).localThumbUri;
            if (localThumbImgPath == null) {
                localThumbImgPath = PathMaker.createThumbImgFilePath(nnddVideo.getDecodeUrl(), false);
            }
            video.thumbUrl = localThumbImgPath;
            video.creationDate = nnddVideo.creationDate;
            video.modificationDate = nnddVideo.modificationDate;
            video.isEconomy = nnddVideo.isEconomy;
            if (oldVideo != null) {
                video.playCount = oldVideo.playCount;
            } else {
                video.playCount = nnddVideo.playCount;
            }

//			libraryManager.update(video, true);
            libraryManager.add(video, false, true);

            logManager.addLog("動画のダウンロード完了:" + video.getDecodeUrl());
            var index: int = searchQueueIndexByQueueId(queueId);
            setStatus(
                "動画保存済\n右クリックから再生できます。",
                DownloadStatusType.COMPLETE,
                queueVideoName,
                index,
                video.getDecodeUrl()
            );

            logManager.addLog("***動画取得完了***");

            this.downloadedListManager.refresh();

            /** ここまで今までのAccess2Nicoの処理 **/
            /** ここから今までのDownloadManagerの処理 **/

            removeHandler();
            isDownloading = false;
            showCountRest();
            retryCount = 0;

            this._nnddDownloader = null;

            /** **/
            if (!isCancel && isDownloading == false) {
                next(false);
            }

        }

        /**
         * ダウンロード失敗リスナー
         * @param event
         *
         */
        public function downlaodFailListener(event: Event): void {
            var status: String = "";
            removeHandler();
            if (event.type == NNDDDownloader.DOWNLOAD_PROCESS_CANCELD) {
                status = "キャンセル";
                logManager.addLog("キャンセル:" + (event.target as NNDDDownloader).saveVideoName);
                logManager.addLog("***動画取得キャンセル***");
                if (isDownloading) {
                    isCancel = true;
                    retryCount = 0;
                    if (timer != null) {
                        timer.stop();
                    }
                    isDownloading = false;
                    var index: int = searchQueueIndexByQueueId(queueId);
                    setStatus("待機中\n" + status, DownloadStatusType.NOT_START, queueVideoName, index);
                    showCountRest();
                }
            } else if (event.type == NNDDDownloader.DOWNLOAD_PROCESS_ERROR) {
                status = "失敗(エラー)";
                logManager.addLog("エラー:" + (event.target as NNDDDownloader).saveVideoName);
                logManager.addLog("***動画取得エラー終了***");
                if (isDownloading) {
                    isRetry = true;
                    retryCount++;
                    if (timer != null) {
                        timer.stop();
                    }
                    isDownloading = false;
                    showCountRest();
                    var index: int = searchQueueIndexByQueueId(queueId);
                    setStatus("待機中\n" + status, DownloadStatusType.NOT_START, queueVideoName, index);

                    // 自動リトライ
                    next(false);
                }
            } else if (event.type == NNDDDownloader.DOWNLOAD_PROCESS_ECONOMY_MODE_SKIP) {
                status = "スキップ(エコノミーモード)";
                logManager.addLog("スキップ(エコノミーモード):" + (event.target as NNDDDownloader).saveVideoName);
                logManager.addLog("***動画取得スキップ(エコノミーモード)***");
                if (isDownloading) {
                    isRetry = false;
                    retryCount = 0;
                    if (timer != null) {
                        timer.stop();
                    }
                    isDownloading = false;
                    showCountRest();
                    var index: int = searchQueueIndexByQueueId(queueId);
                    setStatus("スキップ\n" + status, DownloadStatusType.ECONOMY_SKIP, queueVideoName, index);

                    // 自動リトライ
                    next(false);
                }
            }
            this._nnddDownloader = null;

        }

        /**
         * DLリスト上の指定されたqIndexの動画について、状態を再設定します。
         *
         * @param status
         * @param isDownloaded
         * @param videoName
         * @param qIndex
         * @param path
         * @param newVideoName
         *
         */
        public function setStatus(
            status: String,
            statusType: DownloadStatusType,
            videoName: String,
            qIndex: int,
            path: String = "",
            newVideoName: String = null
        ): void {

            if (qIndex == -1) {
                return;
            }

            var downloadingVideoName: String = videoName;
            if (newVideoName != null) {
                downloadingVideoName = newVideoName;
            }

            if (downloadProvider != null) {
                if (downloadProvider.length > qIndex && downloadProvider[qIndex] != undefined &&
                    downloadProvider[qIndex].col_videoName.indexOf(videoName) != -1) {
                    downloadProvider.setItemAt({
                                                   col_preview: downloadProvider[qIndex].col_preview,
                                                   col_videoName: downloadingVideoName,
                                                   col_videoUrl: downloadProvider[qIndex].col_videoUrl,
                                                   col_status: status,
                                                   col_id: downloadProvider[qIndex].col_id,
                                                   col_downloadedPath: path,
                                                   col_statusType: statusType
                                               }, qIndex);
                }
            }

            var lastIndex: int = videoName.lastIndexOf("- [");
            if (lastIndex != -1) {
                lastIndex -= 1;
            }
            if (lastIndex == -1) {
                lastIndex = videoName.indexOf("\n");
            }
            if (lastIndex == -1) {
                lastIndex = videoName.length;
            }
            videoName = videoName.substring(0, lastIndex);

            //ランキングリストを更新
            var rankingVideoIndex: int = -1;
            if (rankingProvider != null) {
                for (var index: int = 0; index < rankingProvider.length; index++) {
                    if (rankingProvider[index].dataGridColumn_videoName.indexOf(videoName) != -1) {
                        rankingVideoIndex = index;
                        break;
                    }
                }
            }

            if (rankingProvider != null && rankingVideoIndex != -1 && rankingProvider.length > rankingVideoIndex) {
                if (videoName != null &&
                    rankingProvider[rankingVideoIndex].dataGridColumn_videoName.indexOf(videoName) != -1) {
                    this.rankingProvider.setItemAt({
                                                       dataGridColumn_ranking: rankingProvider[rankingVideoIndex].dataGridColumn_ranking,
                                                       dataGridColumn_preview: rankingProvider[rankingVideoIndex].dataGridColumn_preview,
                                                       dataGridColumn_videoName: rankingProvider[rankingVideoIndex].dataGridColumn_videoName,
                                                       dataGridColumn_Info: rankingProvider[rankingVideoIndex].dataGridColumn_Info,
                                                       dataGridColumn_videoInfo: rankingProvider[rankingVideoIndex].dataGridColumn_videoInfo,
                                                       dataGridColumn_condition: status,
                                                       dataGridColumn_videoPath: path,
                                                       dataGridColumn_date: rankingProvider[rankingVideoIndex].dataGridColumn_date,
                                                       dataGridColumn_nicoVideoUrl: rankingProvider[rankingVideoIndex].dataGridColumn_nicoVideoUrl
                                                   }, rankingVideoIndex);
                }
            }

            //検索結果の値を更新
            var searchVideoIndex: int = -1;
            if (searchProvider != null) {
                for (index = 0; index < searchProvider.length; index++) {
                    if (searchProvider[index].dataGridColumn_videoName.indexOf(videoName) != -1) {
                        searchVideoIndex = index;
                        break;
                    }
                }
            }

            if (searchProvider != null && searchVideoIndex != -1 && searchProvider.length > searchVideoIndex) {
                if (videoName != null && searchProvider[searchVideoIndex].dataGridColumn_videoName.indexOf(videoName) !=
                    -1) {
                    this.searchProvider.setItemAt({
                                                      dataGridColumn_ranking: searchProvider[searchVideoIndex].dataGridColumn_ranking,
                                                      dataGridColumn_preview: searchProvider[searchVideoIndex].dataGridColumn_preview,
                                                      dataGridColumn_videoName: searchProvider[searchVideoIndex].dataGridColumn_videoName,
                                                      dataGridColumn_Info: searchProvider[searchVideoIndex].dataGridColumn_Info,
                                                      dataGridColumn_videoInfo: searchProvider[searchVideoIndex].dataGridColumn_videoInfo,
                                                      dataGridColumn_condition: status,
                                                      dataGridColumn_videoPath: path,
                                                      dataGridColumn_date: searchProvider[searchVideoIndex].dataGridColumn_date,
                                                      dataGridColumn_nicoVideoUrl: searchProvider[searchVideoIndex].dataGridColumn_nicoVideoUrl
                                                  }, searchVideoIndex);
                }
            }

            //マイリストの値を更新
            var myListVideoIndex: int = -1;
            if (myListProvider != null) {
                for (index = 0; index < myListProvider.length; index++) {
                    if (myListProvider[index].dataGridColumn_videoName.indexOf(videoName) != -1) {
                        myListVideoIndex = index;
                        break;
                    }
                }
            }

            if (myListProvider != null && myListVideoIndex != -1 && myListProvider.length > myListVideoIndex) {
                if (videoName != null && myListProvider[myListVideoIndex].dataGridColumn_videoName.indexOf(videoName) !=
                    -1) {
                    this.myListProvider.setItemAt({
                                                      dataGridColumn_index: myListProvider[myListVideoIndex].dataGridColumn_index,
                                                      dataGridColumn_preview: myListProvider[myListVideoIndex].dataGridColumn_preview,
                                                      dataGridColumn_videoName: myListProvider[myListVideoIndex].dataGridColumn_videoName,
                                                      dataGridColumn_videoInfo: myListProvider[myListVideoIndex].dataGridColumn_videoInfo,
                                                      dataGridColumn_condition: status,
                                                      dataGridColumn_videoUrl: myListProvider[myListVideoIndex].dataGridColumn_videoUrl,
                                                      dataGridColumn_videoLocalPath: path
                                                  }, myListVideoIndex);
                }
            }
        }

        /**
         * リスナを解除します。
         *
         */
        public function removeHandler(): void {
            this._nnddDownloader.removeEventListener(
                NNDDDownloader.DOWNLOAD_PROCESS_COMPLETE,
                downloadCompleteListener
            );
            this._nnddDownloader.removeEventListener(NNDDDownloader.DOWNLOAD_PROCESS_CANCELD, downlaodFailListener);
            this._nnddDownloader.removeEventListener(NNDDDownloader.DOWNLOAD_PROCESS_ERROR, downlaodFailListener);
            this._nnddDownloader.removeEventListener(
                NNDDDownloader.DOWNLOAD_PROCESS_ECONOMY_MODE_SKIP,
                downlaodFailListener
            );

        }

        /**
         * ダウンロードリストを保存します。
         *
         */
        public function saveDownloadList(): void {

            try {

                var saveXML: XML = <downloadList/>;

                for (var i: int = 0; i < downloadProvider.length; i++) {

                    var xml: XML = <downloadItem/>;
                    xml.videoName = encodeURIComponent(downloadProvider[i].col_videoName);
                    xml.videoUrl = encodeURIComponent(downloadProvider[i].col_videoUrl);
                    xml.status = encodeURIComponent(downloadProvider[i].col_status);
                    xml.downloadedPath = encodeURIComponent(downloadProvider[i].col_downloadedPath);
                    xml.col_id = encodeURIComponent(downloadProvider[i].col_id);
                    xml.statusType = encodeURIComponent(downloadProvider[i].col_statusType.value);

                    saveXML.appendChild(xml);

                }

                try {
                    var saveFile: File = new File(libraryManager.systemFileDir.url + "/downloadList.xml");
                    var fileIO: FileIO = new FileIO(logManager);
                    fileIO.saveXMLSync(saveFile, saveXML);

                    var oldSaveFile: File = new File(libraryManager.libraryDir.url + "/downloadList.xml");
                    if (oldSaveFile.exists) {
                        oldSaveFile.moveToTrash();
                    }

                    logManager.addLog("ダウンロードリストを保存:" + saveFile.nativePath);

                } catch (error: IOError) {
                    Alert.show("ダウンロードリストの保存に失敗しました。\n" + error);
                    logManager.addLog("ダウンロードリストの保存に失敗:" + saveFile.nativePath + "\n" + error + ":" +
                                      error.getStackTrace());
                }

            } catch (error: Error) {
                Alert.show("ダウンロードリストの保存に失敗しました。\n" + error);
                logManager.addLog("ダウンロードリストの保存に失敗:" + saveFile.nativePath + "\n" + error + ":" +
                                  error.getStackTrace());
            }

        }

        /**
         * ダウンロードリストをロードします。
         *
         */
        public function loadDownloadList(): void {

            try {
                downloadItemMap = new Object();
                downloadProvider.removeAll();

                var loadFile: File = new File(libraryManager.systemFileDir.url + "/downloadList.xml");
                if (!loadFile.exists) {
                    loadFile = new File(libraryManager.libraryDir.url + "/downloadList.xml");
                }

                if (loadFile.exists) {

                    try {
                        var fileIO: FileIO = new FileIO(logManager);
                        var loadXML: XML = fileIO.loadXMLSync(loadFile.url, true);
                    } catch (error: IOError) {
                        Alert.show("ダウンロードリストの読み込みに失敗しました。\n" + loadFile.url + "/downloadList.xml", Message.M_ERROR);
                        logManager.addLog("ダウンロードリストの読み込みに失敗:" + loadFile.url + "/downloadList.xml\n" + error + ":" +
                                          error.getStackTrace());
                    }
                    var xmlList: XMLList = loadXML.children();
                    for (var i: int = 0; i < xmlList.length(); i++) {

                        var name: String = decodeURIComponent(xmlList[i].videoName);

                        var id: String = new Date().time + "-" + i;
                        if (xmlList[i].colId != null && xmlList[i].colId != undefined && xmlList[i].colId != "") {
                            id = decodeURIComponent(xmlList[i].col_id);
                        }

                        var status: String = decodeURIComponent(xmlList[i].status);
                        var statusType: DownloadStatusType = DownloadStatusType.NOT_START;

                        if (status.indexOf("動画保存済") != -1) {
                            statusType = DownloadStatusType.COMPLETE;
                            status = "動画保存済\n右クリックから再生できます。";
                        }
                        if ("true" == xmlList[i].isDownloaded) {
                            statusType = DownloadStatusType.COMPLETE;
                            status = "動画保存済\n右クリックから再生できます。";
                        }
                        if ("0" == xmlList[i].statusType) {
                            statusType = DownloadStatusType.COMPLETE;
                            status = "動画保存済\n右クリックから再生できます。";
                        } else if ("1" == xmlList[i].statusType || "2" == xmlList[i].statusType || "3" ==
                                   xmlList[i].statusType || "4" == xmlList[i].statusType) {
                            statusType = DownloadStatusType.NOT_START;
                            status = "待機中";
                        }


                        downloadProvider.addItem({
                                                     col_preview: PathMaker.getThumbImgUrl(decodeURIComponent(xmlList[i].videoUrl)),
                                                     col_videoName: name,
                                                     col_videoUrl: decodeURIComponent(xmlList[i].videoUrl),
                                                     col_status: status,
                                                     col_id: id,
                                                     col_downloadedPath: decodeURIComponent(xmlList[i].downloadedPath),
                                                     col_statusType: statusType
                                                 });
                    }

                    logManager.addLog("ダウンロードリストを読み込み:" + loadFile.nativePath);
                    this.showCountRest();
                } else {
                    logManager.addLog("ダウンロードリストは存在しません:" + loadFile.nativePath);
                }

            } catch (error: Error) {
                Alert.show(
                    "ダウンロードリストの読み込みに失敗しました。\n" + libraryManager.libraryDir.url + "/downloadList.xml",
                    Message.M_ERROR
                );
                logManager.addLog("ダウンロードリストの読み込みに失敗:" + libraryManager.libraryDir.url + "/downloadList.xml\n" + error +
                                  ":" + error.getStackTrace());
            }

        }

        /**
         * 指定されたQueue IDに対応するキューがDLリストの何番目に存在するか返します。
         *
         * @param queueId
         * @return
         *
         */
        private function searchQueueIndexByQueueId(queueId: String): int {
            for (var index: int = 0; downloadProvider.length > index; index++) {
                if (downloadProvider[index].col_id == queueId) {
                    return index;
                }
            }
            return -1;
        }

        /**
         * リトライの最大値を設定します
         *
         * @param value
         *
         */
        public function set retryMaxCount(value: int): void {
            this._retryMaxCount = value;
        }

        /**
         * リトライの最大値を返します
         *
         * @return
         *
         */
        public function get retryMaxCount(): int {
            return this._retryMaxCount;
        }

        public function set maxDlListCount(value: int): void {
            this._maxDlListCount = value;
        }

        public function get maxDlListCount(): int {
            return this._maxDlListCount;
        }

    }
}