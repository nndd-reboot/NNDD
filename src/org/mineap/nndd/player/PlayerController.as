package org.mineap.nndd.player {
    import flash.display.Loader;
    import flash.display.LoaderInfo;
    import flash.display.MovieClip;
    import flash.display.NativeWindowType;
    import flash.display.StageDisplayState;
    import flash.display.StageQuality;
    import flash.events.ErrorEvent;
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.events.HTTPStatusEvent;
    import flash.events.IOErrorEvent;
    import flash.events.MouseEvent;
    import flash.events.TimerEvent;
    import flash.filesystem.File;
    import flash.geom.Rectangle;
    import flash.media.SoundMixer;
    import flash.media.SoundTransform;
    import flash.net.URLRequest;
    import flash.utils.Timer;

    import mx.collections.ArrayCollection;
    import mx.controls.Alert;
    import mx.controls.DataGrid;
    import mx.controls.SWFLoader;
    import mx.controls.Text;
    import mx.controls.videoClasses.VideoError;
    import mx.core.FlexGlobals;
    import mx.core.UIComponent;
    import mx.core.mx_internal;
    import mx.events.AIREvent;
    import mx.events.FlexEvent;
    import mx.events.VideoEvent;
    import mx.formatters.DateFormatter;
    import mx.formatters.NumberFormatter;

    import org.libspark.utils.ForcibleLoader;
    import org.mangui.hls.HLSSettings;
    import org.mangui.hls.constant.HLSSeekMode;
    import org.mangui.osmf.plugins.HLSPlugin;
    import org.mineap.nicovideo4as.MyListLoader;
    import org.mineap.nicovideo4as.WatchVideoPage;
    import org.mineap.nicovideo4as.analyzer.GetRelationResultAnalyzer;
    import org.mineap.nicovideo4as.loader.api.ApiGetRelation;
    import org.mineap.nicovideo4as.model.RelationResultItem;
    import org.mineap.nicovideo4as.util.HtmlUtil;
    import org.mineap.nndd.FileIO;
    import org.mineap.nndd.LogManager;
    import org.mineap.nndd.Message;
    import org.mineap.nndd.NNDDDownloader;
    import org.mineap.nndd.NNDDVideoPageWatcher;
    import org.mineap.nndd.RenewDownloadManager;
    import org.mineap.nndd.history.HistoryManager;
    import org.mineap.nndd.library.ILibraryManager;
    import org.mineap.nndd.library.LibraryManagerBuilder;
    import org.mineap.nndd.library.LocalVideoInfoLoader;
    import org.mineap.nndd.model.NNDDComment;
    import org.mineap.nndd.model.NNDDVideo;
    import org.mineap.nndd.model.PlayList;
    import org.mineap.nndd.model.RssType;
    import org.mineap.nndd.myList.MyListManager;
    import org.mineap.nndd.playList.PlayListManager;
    import org.mineap.nndd.player.comment.Command;
    import org.mineap.nndd.player.comment.CommentManager;
    import org.mineap.nndd.player.comment.Comments;
    import org.mineap.nndd.player.model.PlayerTagString;
    import org.mineap.nndd.user.UserManager;
    import org.mineap.nndd.util.DateUtil;
    import org.mineap.nndd.util.LibraryUtil;
    import org.mineap.nndd.util.NumberUtil;
    import org.mineap.nndd.util.PathMaker;
    import org.mineap.nndd.util.RelationTypeUtil;
    import org.mineap.nndd.util.ThumbInfoAnalyzer;
    import org.mineap.nndd.util.ThumbInfoUtil;
    import org.mineap.nndd.util.WebServiceAccessUtil;
    import org.mineap.util.config.ConfUtil;
    import org.mineap.util.config.ConfigIO;
    import org.mineap.util.config.ConfigManager;
    import org.mineap.util.font.FontUtil;
    import org.osmf.events.LoadEvent;
    import org.osmf.events.MediaFactoryEvent;
    import org.osmf.events.MediaPlayerStateChangeEvent;
    import org.osmf.events.TimeEvent;
    import org.osmf.media.MediaFactory;
    import org.osmf.media.MediaPlayerState;
    import org.osmf.media.PluginInfoResource;
    import org.osmf.net.DynamicStreamingResource;
    import org.osmf.utils.OSMFSettings;

    /**
     * ニコニコ動画からのダウンロードを処理およびその他のGUI関連処理を行う。
     *
     * @author shiraminekeisuke(MineAP)
     *
     */
    public class PlayerController extends EventDispatcher {

        public static const WINDOW_TYPE_SWF: int = 0;
        public static const WINDOW_TYPE_FLV: int = 1;

        public static const NG_LIST_RENEW: String = "NgListRenew";

        private var commentManager: CommentManager;
        private var comments: Comments;

        public var windowType: int = -1;
        public var videoPlayer: VideoPlayer;
        public var videoInfoView: VideoInfoView;
        public var ngListManager: NGListManager;
        public var libraryManager: ILibraryManager;
        public var playListManager: PlayListManager;

        private var windowReady: Boolean = false;

        private var swfLoader: SWFLoader = null;
        private var loader: Loader = null;
        private var isMovieClipPlaying: Boolean = false;

        private var videoDisplay: PatchedVideoDisplay = null;

        private var nicowariSwfLoader: SWFLoader = null;

        private var isStreamingPlay: Boolean = false;

        private var source: String = "";

        private var commentTimer: Timer = new Timer(1000 / 15);
        private var commentTimerVpos: int = 0;

        private var lastSeekTime: Number = new Date().time;

        private var time: Number = 0;

        private var pausing: Boolean = false;

        private var downLoadedURL: String = null;

        private var isPlayListingPlay: Boolean = false;
        private var playingIndex: int = 0;

        private var logManager: LogManager;

        private var mc: MovieClip;
        private var nicowariMC: MovieClip;
        public var swfFrameRate: Number = 0;

        public var sliderChanging: Boolean = false;

        private var nicowariTimer: Timer;

        private var isCounted: Boolean = false;

        private var isMovieClipStopping: Boolean = false;

        public var isPlayerClosing: Boolean = false;

        public var _isEconomyMode: Boolean = false;

        public var videoPlaying: Boolean = false;

        public var searchNNDDServerVideo: Boolean = false;
        public var nnddServerAddress: String = null;
        public var nnddServerPortNum: int = -1;

        private var isHLS: Boolean = false;

        private var renewDownloadManager: RenewDownloadManager;
        private var nnddDownloaderForStreaming: NNDDDownloader;
        private var playerHistoryManager: PlayerHistoryManager;
        private var renewDownloadManagerForOldComment: RenewDownloadManager;

        public static const NICO_WARI_HEIGHT: int = 56;
        public static const NICO_WARI_WIDTH: int = 544;

        public static const NICO_SWF_HEIGHT: int = 384;
        public static const NICO_SWF_WIDTH: int = 512;

        // 640×368
        public static const NICO_VIDEO_WINDOW_HEIGHT: int = 368;
        public static const NICO_VIDEO_WINDOW_WIDTH: int = 512;
        public static const NICO_VIDEO_WINDOW_WIDTH_WIDE_MODE: int = 640;

        // 864×486
        public static const NICO_VIDEO_NEW_WINDOW_WIDTH_WIDE_MODE: int = 864;
        public static const NICO_VIDEO_NEW_WINDOW_WIDTH: int = 654;
        public static const NICO_VIDEO_NEW_WINDOW_HEIGHT: int = 486;

        public static const NICO_VIDEO_PADDING: int = 10;

        public static const WIDE_MODE_ASPECT_RATIO: Number = 1.7;

        //実行中の時報時刻。実行中でない場合はnull。
        private var playingJihou: String = null;

        private var movieEndTimer: Timer = null;

        private var isSwfConverting: Boolean = false;

        private var streamingProgressTimer: Timer = null;

        private var _videoID: String = null;

        private var nnddDownloaderForWatch: NNDDDownloader = null;

        private var lastFrame: int = 0;

        private var lastNicowariFrame: int = 0;

        private var myListLoader: MyListLoader = null;

        private var nicowariCloseTimer: Timer = null;

        private var configIO: ConfigIO;

        private var streamingRetryCount: int = 0;

        private var nicoVideoPageGetRetryTimer: Timer;

        private var nicoVideoAccessRetryTimer: Timer;

        private var nicoRelationInfoLoader: ApiGetRelation = null;

        private var lastLoadedBytes: Number = 0;

        private var _isLengthwisePreferred: Boolean = true;

        /** 新サイズ 864×486ピクセル 旧サイズ 640×368ピクセル */
        private var _useOldVersionVideoSize: Boolean = false;

        private var _fmsToken: String;

        private var _dmcHeartbeatTimer: Timer = null;

        [Embed(source="/player/NNDDicons_play_20x20.png")]
        private var icon_Play: Class;

        [Embed(source="/player/NNDDicons_pause_20x20.png")]
        private var icon_Pause: Class;

        [Embed(source="/player/NNDDicons_stop_20x20.png")]
        private var icon_Stop: Class;


        /**
         * 動画の再生を行うPlayerを管理するPlayerControllerです。<br>
         * FLVやMP4を再生するためのPlayerとSWFを再生するためのPlayerを管理し、<br>
         * 必要に応じて切り替えます。<br>
         *
         */
        public function PlayerController() {
            OSMFSettings.enableStageVideo = false;
            HLSSettings.maxBufferLength = 300;
            HLSSettings.maxBackBufferLength = 300;
            HLSSettings.seekMode = HLSSeekMode.ACCURATE_SEEK;

            this.logManager = LogManager.instance;
            this.libraryManager = LibraryManagerBuilder.instance.libraryManager;
            this.playListManager = PlayListManager.instance;
            this.videoPlayer = new VideoPlayer();
            this.videoInfoView = new VideoInfoView();
            ConfigManager.getInstance().reload();
            this.videoPlayer.init(this, videoInfoView, logManager);
            this.videoInfoView.init(this, videoPlayer, logManager);
            this.videoPlayer.addEventListener(AIREvent.WINDOW_COMPLETE, function (): void {
                setFont(FontUtil.applicationFont);
                setFontSize(FontUtil.applicationFontSize);
                videoInfoView.activate();
                videoPlayer.activate();
            });
            this.ngListManager = new NGListManager(this, videoPlayer, videoInfoView, logManager);
            if (libraryManager != null) {
                if (!this.ngListManager.loadNgList(LibraryManagerBuilder.instance.libraryManager.systemFileDir)) {
                    this.ngListManager.loadNgList(LibraryManagerBuilder.instance.libraryManager.libraryDir);
                }
            }
            this.commentTimer.addEventListener(TimerEvent.TIMER, commentTimerHandler);
            this.commentManager = new CommentManager(videoPlayer, videoInfoView, this);

            this.playerHistoryManager = new PlayerHistoryManager();
        }

        /**
         * デストラクタという名前だがController再利用のためのクリーンアップを行う
         * Comments、NgListにnullを代入してGCを助けます。
         *
         */
        public function destructor(): void {

            isMovieClipStopping = false;

            if (this.movieEndTimer != null) {
                this.movieEndTimer.stop();
                this.movieEndTimer = null;
            }

            if (this.commentTimer != null) {
                this.commentTimer.stop();
                this.commentTimer.reset();
            } else {
                this.commentTimer = new Timer(1000 / 15);
                this.commentTimer.addEventListener(TimerEvent.TIMER, commentTimerHandler);
            }

            if (this._dmcHeartbeatTimer !== null && this._dmcHeartbeatTimer.running) {
                this._dmcHeartbeatTimer.stop();
            }

            if (this.comments != null) {
                this.comments.destructor();
            }
            this.comments = null;
//			this.ngList = null;

            if (videoDisplay != null) {
                try {
                    videoDisplay.stop();
                } catch (error: VideoError) {
                    trace(error.getStackTrace());
                }
                removeVideoDisplayEventListeners(videoDisplay);
                videoDisplay.source = null;
                videoDisplay = null;
                this.videoPlayer.canvas_video.removeAllChildren();
            }

            isMovieClipPlaying = false;
            if (loader != null && !isSwfConverting) {
                SoundMixer.stopAll();
                loader.unloadAndStop(true);
//				removeMovieClipEventHandlers(loader);
                loader = null;
                this.videoPlayer.canvas_video.removeAllChildren();
                isSwfConverting = false;
            }
            if (swfLoader != null && !isSwfConverting) {
                SoundMixer.stopAll();
                swfLoader.unloadAndStop(true);
                swfLoader = null;
                this.videoPlayer.canvas_video.removeAllChildren();
                isSwfConverting = false;
            }

            if (this.nicowariSwfLoader != null) {
                videoPlayer.canvas_nicowari.removeAllChildren();
                if (nicowariMC != null) {
                    this.pauseByNicowari(true);
                }
            }

            if (videoPlayer != null && videoPlayer.canvas_nicowari != null) {
                videoPlayer.canvas_nicowari.removeAllChildren();
                videoPlayer.canvas_nicowari.setConstraintValue("backgroundColor", new int("0x969696"));

            }

            if (streamingProgressTimer != null) {
                streamingProgressTimer.stop();
                streamingProgressTimer = null;
            }

            playingJihou = null;

            if (nnddDownloaderForWatch != null) {
                nnddDownloaderForWatch.close(false, false);
                nnddDownloaderForWatch = null;
            }

            if (myListLoader != null) {
                myListLoader.close();
                myListLoader = null;
            }

            this.lastFrame = 0;
            this.lastNicowariFrame = 0;

            this.lastLoadedBytes = 0;

            if (videoInfoView != null) {
                videoInfoView.pubUserLinkButtonText = "(未取得)";
                videoInfoView.pubUserNameIconUrl = null;
                videoInfoView.pubUserName = "(未取得)";

                if (videoInfoView.pubUserLinkButton != null) {
                    videoInfoView.pubUserLinkButton.label = videoInfoView.pubUserLinkButtonText;
                    videoInfoView.image_pubUserIcon.source = videoInfoView.pubUserNameIconUrl;
                    videoInfoView.label_pubUserName.text = videoInfoView.pubUserName;
                }
            }

            isCounted = false;

        }

        /**
         * 与えられた引数でPlayerの準備を行います。<br>
         * autoPlayにtrueを設定した場合、init()の完了後、準備ができ次第再生が行われます。<br>
         * <b>playMovie()を使ってください。</b>
         *
         * @param videoPath
         * @param windowType
         * @param comments
         * @param thumbInfoPath
         * @param ngList
         * @param autoPlay
         * @param isStreamingPlay
         * @param downLoadedURL
         * @param isPlayListingPlay
         *
         */
        private function init(
            videoPath: String,
            windowType: int,
            comments: Comments,
            thumbInfoPath: String,
            autoPlay: Boolean = false,
            isStreamingPlay: Boolean = false,
            downLoadedURL: String = null,
            isPlayListingPlay: Boolean = false,
            videoId: String = ""
        ): void {
            this.destructor();

            if (videoPlayer != null) {
                videoPlayer.resetInfo();
                if (videoPlayer.stage.displayState != StageDisplayState.FULL_SCREEN_INTERACTIVE) {
                    videoPlayer.restore();
                }
            }

            if (videoInfoView != null) {
                videoInfoView.resetInfo();
//				videoInfoView.restore();
            }

            videoPlayer.setControllerEnable(false);

            this._videoID = null;
            if (videoId != null && videoId != "") {
                this._videoID = videoId;
            }

            this.windowReady = false;
            this.source = videoPath;
            this.comments = comments;
            this.time = (new Date).time;
            this.isStreamingPlay = isStreamingPlay;
            this.downLoadedURL = downLoadedURL;
            this.isPlayListingPlay = isPlayListingPlay;
            this.windowType = windowType;

            if (!isPlayListingPlay) {
                this.videoInfoView.resetPlayList();
            }

            this.videoPlayer.videoController.resetAlpha(true);
            this.videoPlayer.updateFrameRate();

            var value: String = ConfigManager.getInstance().getItem("isLengthwisePreferred");
            if (value != null) {
                this.isLengthwisePreferred = ConfUtil.parseBoolean(value);
            } else {
                this.isLengthwisePreferred = true;
                ConfigManager.getInstance().setItem("isLengthwisePreferred", this._isLengthwisePreferred);
            }

            if (isStreamingPlay) {
                if (streamingProgressTimer != null) {
                    streamingProgressTimer.stop();
                    streamingProgressTimer = null;
                }

                this.videoPlayer.label_playSourceStatus.text = "Streaming:0%";
                videoInfoView.connectionType = "Streaming";
                streamingProgressTimer = new Timer(500);
                streamingProgressTimer.addEventListener(TimerEvent.TIMER, streamingProgressHandler);
                streamingProgressTimer.start();

                if (this.videoPlayer.title == null) {
                    this.videoPlayer.addEventListener(FlexEvent.CREATION_COMPLETE, function (): void {
                        videoPlayer.title = downLoadedURL.substr(downLoadedURL.lastIndexOf("/") + 1);
                    });
                } else {
                    this.videoPlayer.title = downLoadedURL.substr(downLoadedURL.lastIndexOf("/") + 1);
                }
            } else {
                this.videoPlayer.label_playSourceStatus.text = "[Local]";
                videoInfoView.connectionType = "Local";
                this.streamingRetryCount = 0;
                if (this.videoPlayer.title == null) {
                    this.videoPlayer.addEventListener(FlexEvent.CREATION_COMPLETE, function (): void {
                        videoPlayer.title = videoPath.substr(videoPath.lastIndexOf("/") + 1);
                    });
                } else {
                    this.videoPlayer.title = videoPath.substr(videoPath.lastIndexOf("/") + 1);
                }
                var file: File = new File(videoPath);
                if (!file.exists) {
                    Alert.show("動画が既に存在しません。\n動画が移動されたか、削除されている可能性があります。", "エラー", 4, this.videoPlayer);
                    logManager.addLog("動画が既に存在しません。動画が移動されたか、削除されている可能性があります。:" + file.nativePath);
                    return;
                }

            }

            /* 動画の再生時にコメント・ニコ割を更新するかどうか */
            if (!isStreamingPlay && this.videoInfoView.isRenewCommentEachPlay) {
                //ストリーミング再生じゃない時は更新を試みる

                logManager.addLog(Message.START_PLAY_EACH_COMMENT_DOWNLOAD);
                videoPlayer.label_downloadStatus.text = Message.START_PLAY_EACH_COMMENT_DOWNLOAD;

                if (this._videoID == null) {
                    this._videoID = PathMaker.getVideoID(videoPath);
                }

                if (this._videoID != null && PathMaker.getVideoID(videoPath) == LibraryUtil.getVideoKey(videoPath)) {
                    if ((UserManager.instance.user == null || UserManager.instance.password == null) ||
                        (UserManager.instance.user == "" || UserManager.instance.password == "")) {
                        /* ログインしていないとき*/
                        logManager.addLog(Message.FAIL_PLAY_EACH_COMMENT_DOWNLOAD + "(ログインしていません)");
                    }

                    var videoUrl: String = "http://www.nicovideo.jp/watch/" + PathMaker.getVideoID(this._videoID);

                    renewCommentAtStart(PathMaker.getVideoID(this._videoID), videoPath, thumbInfoPath, autoPlay);
                } else {

                    logManager.addLog(Message.FAIL_PLAY_EACH_COMMENT_DOWNLOAD + "(動画IDが存在しません)");
                    videoPlayer.label_downloadStatus.text = Message.FAIL_PLAY_EACH_COMMENT_DOWNLOAD + "(動画IDが存在しません)";

                    var timer: Timer = new Timer(1000, 1);
                    timer.addEventListener(TimerEvent.TIMER_COMPLETE, function (event: TimerEvent): void {
                        initStart(videoPath, thumbInfoPath, autoPlay);

                        timer.stop();
                        timer = null;

                    });
                    timer.start();

                }
            } else {
                //ストリーミング再生の時は気にしない(マイリストの一覧だけは取りに行く)

                this._videoID = videoId;

                if (this._videoID == null || this._videoID == "") {
                    this._videoID = PathMaker.getVideoID(videoPlayer.title);
                }

                logManager.addLog("マイリスト一覧の更新を開始:" + this._videoID);

                if (this._videoID != null && this._videoID != "") {

                    if (UserManager.instance.user != null && UserManager.instance.user != "" &&
                        UserManager.instance.password != null && UserManager.instance.password != "") {

                        myListGroupUpdate(PathMaker.getVideoID(this._videoID));

                    } else {
                        //ログインしてください。
                        logManager.addLog("マイリスト一覧の更新に失敗(ログインしていない)");
                    }

                } else {
                    //
                    logManager.addLog("マイリスト一覧の更新に失敗(動画IDが取得できない)");
                }

                initStart(videoPath, thumbInfoPath, autoPlay);
            }

        }

        /**
         * VideoDisplay、もしくはSWFLoaderを準備し、必要に応じて動画の再生を開始します。
         *
         * @param videoPath 動画のパス
         * @param thumbInfoPath サムネイル情報のパス
         * @param autoPlay 動画の再生を開始するかどうか
         */
        private function initStart(videoPath: String, thumbInfoPath: String, autoPlay: Boolean): void {
//			trace(videoPlayer.stage.quality);

            try {
                if (_isEconomyMode) {
                    videoPlayer.label_economyStatus.text = "エコノミーモード";
                } else {
                    videoPlayer.label_economyStatus.text = "";
                }

                videoPlayer.canvas_video.toolTip = null;

                if (isPlayerClosing) {
                    stop();
                    destructor();
                    return;
                }

                commentTimerVpos = 0;

                var text: Text = new Text();
                text.text = "ユーザーニコ割がダウンロード済であれば、この領域で再生されます。\n画面をダブルクリックすると非表示に出来ます。";
                text.setConstraintValue("left", 10);
                text.setConstraintValue("top", 10);
                videoPlayer.canvas_nicowari.addChild(text);

                videoPlayer.label_downloadStatus.text = "";
                videoInfoView.image_thumbImg.source = "";
                videoInfoView.text_info.htmlText = "(タイトルを取得中)<br />(投稿日時を取得中)<br />再生: コメント: マイリスト:";

                if (isStreamingPlay) {
                    //最新の情報はDL済みなのでそれを使う
                    setInfo(
                        downLoadedURL,
                        thumbInfoPath,
                        true
                    );

                    videoInfoView.image_thumbImg.source =
                        thumbInfoPath.substring(0, thumbInfoPath.lastIndexOf("/")) + "/nndd[ThumbImg].jpeg";
                } else {
                    setInfo(videoPath, thumbInfoPath, false);

                    var nnddVideo: NNDDVideo = libraryManager.isExist(PathMaker.getVideoID(videoPath));

                    if (nnddVideo != null) {
                        videoInfoView.image_thumbImg.source = decodeURIComponent(nnddVideo.thumbUrl);
                    }
                }

                changeFps(videoInfoView.fps);

                videoPlayer.videoController.label_time.text = "0:00/0:00";
                videoPlayer.videoController_under.label_time.text = "0:00/0:00";

                if (videoInfoView.isShowAlwaysNicowariArea) {
                    //ニコ割領域を常に表示する
                    videoPlayer.showNicowariArea();

                } else {
                    //ニコ割は再生時のみ表示
                    videoPlayer.hideNicowariArea();

                }

                var video: NNDDVideo = libraryManager.isExist(LibraryUtil.getVideoKey(_videoID));
                if (video != null) {
                    HistoryManager.instance.addVideoByNNDDVideo(video);
                } else {
                    video = new NNDDVideo(
                        "http://www.nicovideo.jp/watch/" + PathMaker.getVideoID(_videoID),
                        videoPlayer.title,
                        false,
                        null,
                        null,
                        null,
                        PathMaker.getThumbImgUrl(PathMaker.getVideoID(_videoID))
                    );

                    HistoryManager.instance.addVideoByNNDDVideo(video, null, false);
                }

                if (windowType == PlayerController.WINDOW_TYPE_FLV) {
                    //WINDOW_TYPE_FLVで初期化する場合の処理

                    isMovieClipPlaying = false;

                    videoDisplay = new PatchedVideoDisplay();

                    videoPlayer.label_downloadStatus.text = "";

                    if (isStreamingPlay) {
                        videoPlayer.label_downloadStatus.text = "バッファ中...";
                        videoDisplay.addEventListener(
                            MediaPlayerStateChangeEvent.MEDIA_PLAYER_STATE_CHANGE,
                            mediaPlayerStateChanged
                        );
                    }

                    videoPlayer.canvas_video.removeAllChildren();
                    videoPlayer.canvas_video.addChild(videoDisplay);

                    videoDisplay.setConstraintValue("bottom", 0);
                    videoDisplay.setConstraintValue("left", 0);
                    videoDisplay.setConstraintValue("right", 0);
                    videoDisplay.setConstraintValue("top", 0);

                    if (videoPath.length > 4 &&
                        (videoPath.substr(0, 4) == "http" || videoPath.substr(0, 4) == "rtmp")) {
                        // http or rtmp
                        videoInfoView.videoServerUrl = videoPath.substring(0, videoPath.lastIndexOf("/"));
                    } else {
                        // file(ローカル)
                        videoInfoView.videoServerUrl = decodeURIComponent(videoPath);
                        var messageServerUrl: String = PathMaker.createNomalCommentPathByVideoPath(videoPath);
                        if (messageServerUrl != null) {
                            videoInfoView.messageServerUrl = decodeURIComponent(messageServerUrl);
                        }
                    }
                    videoInfoView.videoType = "FLV/MP4";

                    videoDisplay.autoPlay = autoPlay;

                    if (videoPath.indexOf("rtmp") == 0 && this._fmsToken != null) {

                        // RTMPの時
                        // FIXME: 未実装。だれかやり方教えて・・・。

//						var resource:DynamicStreamingResource = new DynamicStreamingResource("smile-chefsf.nicovideo.jp");
//						resource.urlIncludesFMSApplicationInstance = true;
//						var vector:Vector.<DynamicStreamingItem> = new Vector.<DynamicStreamingItem>(1);
//						vector[0] = new DynamicStreamingItem(videoPath, 1200);
//						resource.streamItems = vector;
//						var element:VideoElement = new VideoElement(resource);
//
//						videoDisplay.source = element;

//						(videoDisplay.mx_internal::videoPlayer as MediaPlayer).authenticateWithToken(this._fmsToken);
                    } else {
                        var factory: MediaFactory = this.videoDisplay.mx_internal::mediaFactory;

                        factory.addEventListener(
                            MediaFactoryEvent.PLUGIN_LOAD,
                            function (event: MediaFactoryEvent): void {
                                if (_dmcHeartbeatTimer !== null && !_dmcHeartbeatTimer.running) {
                                    _dmcHeartbeatTimer.start();
                                }

                                if (isHLS) {
                                    // HLSの場合, 動画ソースはDynamicStreamingResouceオブジェクトにする必要がある
                                    videoDisplay.source = new DynamicStreamingResource(videoPath);
                                } else {
                                    videoDisplay.source = videoPath;
                                }
                            }
                        );

                        factory.addEventListener(
                            MediaFactoryEvent.PLUGIN_LOAD_ERROR,
                            function (event: MediaFactoryEvent): void {
                                trace("Error: OSFM HLS Plugin Load Failure.");
                                throw new Error("OSFM HLS Plugin Load Failure.");
                            }
                        );

                        factory.loadPlugin(new PluginInfoResource(new HLSPlugin()));
                    }
                    videoDisplay.autoRewind = false;
                    videoDisplay.volume = videoPlayer.videoController.slider_volume.value;
                    videoPlayer.videoController_under.slider_volume.value =
                        videoPlayer.videoController.slider_volume.value;

                    addVideoDisplayEventListeners(videoDisplay);

                    commentManager.initComment(comments, videoPlayer.canvas_video);
                    commentManager.setCommentAlpha(videoInfoView.commentAlpha / 100);

                    windowReady = true;

                    if (autoPlay && !isStreamingPlay) {
                        time = (new Date).time;
                        commentTimer.start();
                    }

                    videoDisplay.addEventListener(LoadEvent.BYTES_LOADED_CHANGE, byteloadedChangedEventHandler);
                    videoDisplay.addEventListener(TimeEvent.CURRENT_TIME_CHANGE, osmfCurrentTimeChangeEventHandler);
                    videoDisplay.addEventListener(MouseEvent.CLICK, function (event: MouseEvent): void {
                        event.currentTarget.setFocus();
                    });

                    videoPlayer.videoController.button_play.setStyle("icon", icon_Pause);
                    videoPlayer.videoController_under.button_play.setStyle("icon", icon_Pause);
                    setVolume(videoPlayer.videoController.slider_volume.value);

//					if(videoInfoView.visible){
//						videoInfoView.restore();
//					}
                    if (videoPlayer.stage.displayState != StageDisplayState.FULL_SCREEN_INTERACTIVE) {
                        videoPlayer.restore();
                    }

//					if(videoInfoView.visible){
//						videoInfoView.activate();
//					}
//					videoPlayer.activate();
                    videoPlayer.showVideoPlayerAndVideoInfoView(true);

                    windowResized(false);

                    videoPlayer.setControllerEnable(true);

                } else if (windowType == PlayerController.WINDOW_TYPE_SWF) {
                    //WINODW_TYPE_SWFで初期化する場合の処理

                    isMovieClipPlaying = true;
                    isSwfConverting = true;

                    videoPlayer.label_downloadStatus.text = "SWFを変換しています...";

                    loader = new Loader();
                    loader.contentLoaderInfo.addEventListener(Event.COMPLETE, convertCompleteHandler);
                    var fLoader: ForcibleLoader = new ForcibleLoader(loader);
                    swfLoader = new SWFLoader();
                    swfLoader.addChild(loader);

                    videoPlayer.canvas_video.removeAllChildren();
                    videoPlayer.canvas_video.addChild(swfLoader);

                    swfLoader.setConstraintValue("bottom", 0);
                    swfLoader.setConstraintValue("left", 0);
                    swfLoader.setConstraintValue("right", 0);
                    swfLoader.setConstraintValue("top", 0);

                    swfLoader.addEventListener(MouseEvent.CLICK, function (event: MouseEvent): void {
                        event.currentTarget.setFocus();
                    });

                    commentManager.initComment(comments, videoPlayer.canvas_video);
                    commentManager.setCommentAlpha(videoInfoView.commentAlpha / 100);

                    windowReady = true;

                    if (videoPath.length > 4 && videoPath.substr(0, 4) == "http") {
                        videoInfoView.videoServerUrl = videoPath.substring(0, videoPath.lastIndexOf("/"));
                    } else {
                        // file(ローカル)
                        videoInfoView.videoServerUrl = decodeURIComponent(videoPath);
                        var messageServerUrl: String = PathMaker.createNomalCommentPathByVideoPath(videoPath);
                        if (messageServerUrl != null) {
                            videoInfoView.messageServerUrl = decodeURIComponent(messageServerUrl);
                        }
                    }
                    videoInfoView.videoType = "SWF";
                    if (autoPlay) {
                        fLoader.load(new URLRequest(videoPath));
                    }

                    var timer: Timer = new Timer(500, 4);
                    timer.addEventListener(TimerEvent.TIMER, function (): void {
                        windowResized(false);
                    });
                    timer.start();

                    videoPlayer.videoController_under.button_play.setStyle("icon", icon_Pause);
                    videoPlayer.videoController.button_play.setStyle("icon", icon_Pause);

//					if(videoInfoView.visible){
//						videoInfoView.restore();
//					}

                    if (videoPlayer.stage.displayState != StageDisplayState.FULL_SCREEN_INTERACTIVE) {
                        videoPlayer.restore();
                    }

//					if(videoInfoView.visible){
//						videoInfoView.activate();
//					}
//					videoPlayer.activate();
                    videoPlayer.showVideoPlayerAndVideoInfoView(true);

                    videoPlayer.setControllerEnable(true);

                }

                if (videoInfoView != null && videoInfoView.tabNavigator_comment != null) {
                    if (videoInfoView.tabNavigator_comment.selectedIndex == 1) {
                        // 過去コメントタブが選択されてるときはコメントを再ロード
                        videoInfoView.reloadOldComment();
                    } else {
                        // 選択されていないときは時刻をリセット
                        videoInfoView.resetOldCommentDate();
                    }
                }

                return;
            } catch (error: Error) {
                trace(error.getStackTrace());
                logManager.addLog(error + ":" + error.getStackTrace());
            }
        }

        public function get videoRectangle(): Rectangle {
            var uicomp: UIComponent = videoPlayer.vbox_videoPlayer;

            var videoRectangle: Rectangle = new Rectangle(uicomp.x, uicomp.y, uicomp.width, uicomp.height);
//			if (videoDisplay != null)
//			{
//				videoRectangle = new Rectangle(videoDisplay.x, videoDisplay.y, videoDisplay.width, videoDisplay.height);
//			}
//			else if (swfLoader != null)
//			{
//				videoRectangle = new Rectangle(swfLoader.x, swfLoader.y, swfLoader.width, swfLoader.height);
//			}
//			else
//			{
//				videoRectangle =
//			}

            return videoRectangle;
        }

        /**
         * コメントを最新に更新します
         *
         * @param videoId
         * @param videoPath
         * @param thumbInfoPath
         * @param autoPlay
         *
         */
        private function renewCommentAtStart(
            videoId: String,
            videoPath: String,
            thumbInfoPath: String,
            autoPlay: Boolean
        ): void {

            var videoName: String = PathMaker.getVideoName(videoPath);

            if (renewDownloadManager != null) {
                renewDownloadManager.close();
                renewDownloadManager = null;
            }

            renewDownloadManager = new RenewDownloadManager(null, logManager);
            renewDownloadManager.addEventListener(
                RenewDownloadManager.PROCCESS_COMPLETE,
                function (event: Event): void {
                    var video: NNDDVideo = libraryManager.isExist(PathMaker.getVideoID(renewDownloadManager.savedVideoFile.url));
                    if (video == null) {
                        try {
                            video = new LocalVideoInfoLoader().loadInfo(videoPath);
                            video.creationDate = new File(videoPath).creationDate;
                            video.modificationDate = new File(videoPath).modificationDate;
                        } catch (error: Error) {
                            video = new NNDDVideo(videoPath);
                        }
                        libraryManager.add(video, false);
                        video = libraryManager.isExist(video.key);
                    }
                    videoPath = video.file.url;
                    if (videoPlayer != null) {
                        videoPlayer.title = video.file.name;
                    }
                    var thumbUrl: String = (event.currentTarget as RenewDownloadManager).localThumbUri;
                    var isLocal: Boolean = false;
                    try {
                        //すでにローカルのファイルが設定されてるなら再設定しない。
                        var file: File = new File(video.thumbUrl);
                        if (file.exists) {
                            isLocal = true;
                        }
                    } catch (e: Error) {
                        trace(e);
                    }

                    //thumbUrlのURLがローカルで無ければ無条件で上書き
                    if (!isLocal) {
                        if (thumbUrl != null) {
                            //新しく取得したthumbUrlを設定
                            video.thumbUrl = thumbUrl;
                        } else if (video.thumbUrl == null || video.thumbUrl == "") {
                            //thumbUrlが取れない==動画は削除済
                            var videoId: String = PathMaker.getVideoID(_videoID);
                            if (videoId != null) {
                                video.thumbUrl = PathMaker.getThumbImgUrl(videoId);
                            } else {
                                video.thumbUrl = "";
                            }
                        }
                    }

                    libraryManager.update(video, false);


                    var videoMin: int = video.time / 60;
                    ++videoMin;

                    var commentPath: String = PathMaker.createNomalCommentPathByVideoPath(video.getDecodeUrl());
                    var ownerCommentPath: String = PathMaker.createOwnerCommentPathByVideoPath(video.getDecodeUrl());
                    comments = new Comments(
                        commentPath,
                        ownerCommentPath,
                        getCommentListProvider(),
                        getOwnerCommentListProvider(),
                        ngListManager,
                        videoInfoView.isShowOnlyPermissionComment,
                        videoInfoView.isHideSekaShinComment,
                        videoInfoView.showCommentCountPerMin * videoMin,
                        videoInfoView.showOwnerCommentCountPerMin * videoMin,
                        videoInfoView.isNgUpEnable
                    );

//				renewDownloadManager.close();

                    renewDownloadManager = null;

                    myListGroupUpdate(PathMaker.getVideoID(_videoID));

                    initStart(videoPath, thumbInfoPath, autoPlay);
                }
            );
//			renewDownloadManager.addEventListener(NNDDDownloader.COMMENT_GET_SUCCESS, getProgressListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.GETFLV_API_ACCESS_SUCCESS, getProgressListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.LOGIN_SUCCESS, getProgressListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.NICOWARI_GET_SUCCESS, getProgressListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.OWNER_COMMENT_GET_SUCCESS, getProgressListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.THUMB_IMG_GET_SUCCESS, getProgressListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.THUMB_INFO_GET_SUCCESS, getProgressListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.VIDEO_GET_SUCCESS, getProgressListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.WATCH_SUCCESS, getProgressListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.DOWNLOAD_PROCESS_COMPLETE, getProgressListener);
//
//			renewDownloadManager.addEventListener(NNDDDownloader.COMMENT_GET_FAIL, getFailListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.GETFLV_API_ACCESS_FAIL, getFailListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.LOGIN_FAIL, getFailListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.NICOWARI_GET_FAIL, getFailListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.OWNER_COMMENT_GET_FAIL, getFailListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.THUMB_IMG_GET_FAIL, getFailListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.THUMB_INFO_GET_FAIL, getFailListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.VIDEO_GET_FAIL, getFailListener);
//			renewDownloadManager.addEventListener(NNDDDownloader.WATCH_FAIL, getFailListener);

            renewDownloadManager.addEventListener(
                RenewDownloadManager.PROCCESS_STATUS_UPDATE,
                function (event: Event): void {
                    trace(event);
                    logManager.addLog(RenewDownloadManager.PROCCESS_STATUS_UPDATE + ":" + event);
                }
            );
            renewDownloadManager.addEventListener(RenewDownloadManager.PROCCESS_FAIL, function (event: Event): void {
                renewDownloadManager = null;
                videoPlayer.label_downloadStatus.text = Message.FAIL_PLAY_EACH_COMMENT_DOWNLOAD;
                logManager.addLog(Message.FAIL_PLAY_EACH_COMMENT_DOWNLOAD);

                var timer: Timer = new Timer(1000, 1);
                timer.addEventListener(TimerEvent.TIMER_COMPLETE, function (event: Event): void {
                    myListGroupUpdate(PathMaker.getVideoID(_videoID));
                    initStart(videoPath, thumbInfoPath, autoPlay);
                });
                timer.start();
            });
            renewDownloadManager.addEventListener(RenewDownloadManager.PROCCESS_CANCEL, function (event: Event): void {
                renewDownloadManager = null;
                videoPlayer.label_downloadStatus.text = Message.PLAY_EACH_COMMENT_DOWNLOAD_CANCEL;
                logManager.addLog(Message.PLAY_EACH_COMMENT_DOWNLOAD_CANCEL);

                var timer: Timer = new Timer(1000, 1);
                timer.addEventListener(TimerEvent.TIMER_COMPLETE, function (): void {
                    myListGroupUpdate(PathMaker.getVideoID(_videoID));
                    initStart(videoPath, thumbInfoPath, autoPlay);
                });
                timer.start();
            });

            if (this.videoInfoView.isRenewOtherCommentWithCommentEachPlay) {
                renewDownloadManager.renewForOtherVideo(
                    UserManager.instance.user,
                    UserManager.instance.password,
                    PathMaker.getVideoID(videoId),
                    videoName,
                    new File(videoPath.substring(0, videoPath.lastIndexOf("/") + 1)),
                    videoInfoView.isAppendComment,
                    null,
                    (FlexGlobals.topLevelApplication as NNDD).getSaveCommentMaxCount(),
                    FlexGlobals.topLevelApplication.getUseOldTypeCommentGet()
                );
            } else {
                renewDownloadManager.renewForCommentOnly(
                    UserManager.instance.user,
                    UserManager.instance.password,
                    PathMaker.getVideoID(videoId),
                    videoName,
                    new File(videoPath.substring(0, videoPath.lastIndexOf("/") + 1)),
                    videoInfoView.isAppendComment,
                    null,
                    (FlexGlobals.topLevelApplication as NNDD).getSaveCommentMaxCount(),
                    FlexGlobals.topLevelApplication.getUseOldTypeCommentGet()
                );
            }
        }

        /**
         * 過去コメントを取得する
         * @param date
         *
         */
        public function getOldCommentFromNico(date: Date): void {

            if (renewDownloadManagerForOldComment != null) {
                // 既に実行中。中止。
                renewDownloadManagerForOldComment.close();
                renewDownloadManagerForOldComment = null;
                videoInfoView.button_oldComment_reloadFromNico.label = "更新(ニコニコ動画)";
                logManager.addLog("過去コメント取得を中止");

            } else {
                // 新規実行

                videoInfoView.button_oldComment_reloadFromNico.label = "キャンセル";
                logManager.addLog("過去ログの取得を開始:" + DateUtil.getDateString(date));

                renewDownloadManagerForOldComment = new RenewDownloadManager(null, LogManager.instance);
                renewDownloadManagerForOldComment.addEventListener(
                    NNDDDownloader.GETWAYBACKKEY_API_ACCESS_FAIL,
                    function (event: Event): void {
                        videoInfoView.button_oldComment_reloadFromNico.label = "更新(ニコニコ動画)";
                        logManager.addLog("過去ログの取得に失敗:" + event);

                        FlexGlobals.topLevelApplication.activate();
                        Alert.show(
                            "過去ログの取得に失敗しました。\nご利用のアカウントでは過去ログを取得できない可能性があります。\n(この機能はプレミアムアカウントでのみ利用可能です。)",
                            Message.M_ERROR,
                            4,
                            videoPlayer
                        );
                    }
                );
                renewDownloadManagerForOldComment.addEventListener(
                    RenewDownloadManager.PROCCESS_CANCEL,
                    function (event: Event): void {
                        videoInfoView.button_oldComment_reloadFromNico.label = "更新(ニコニコ動画)";
                        logManager.addLog("過去ログの取得をキャンセル:" + event);

                        renewDownloadManagerForOldComment = null;
                    }
                );
                renewDownloadManagerForOldComment.addEventListener(
                    RenewDownloadManager.PROCCESS_COMPLETE,
                    function (event: Event): void {
                        logManager.addLog("過去ログの取得に成功:" + event);
                        //コメントを再読み込み
                        reloadLocalComment(date);

                        renewDownloadManagerForOldComment.close();
                        renewDownloadManagerForOldComment = null;

                        videoInfoView.button_oldComment_reloadFromNico.label = "更新(ニコニコ動画)";

                    }
                );
                renewDownloadManagerForOldComment.addEventListener(
                    RenewDownloadManager.PROCCESS_FAIL,
                    function (event: Event): void {
                        videoInfoView.button_oldComment_reloadFromNico.label = "更新(ニコニコ動画)";
                        logManager.addLog("過去ログの取得に失敗:" + event);

                        renewDownloadManagerForOldComment = null;

                        FlexGlobals.topLevelApplication.activate();
                        Alert.show(
                            "過去ログの取得に失敗しました。",
                            Message.M_ERROR,
                            4,
                            videoPlayer
                        );
                    }
                );

                var videoId: String = PathMaker.getVideoID(this._videoID);
                var videoName: String = null;
                var videoPath: File = null;
                if (isStreamingPlay) {
                    videoName = "nndd.flv";
                    videoPath = LibraryManagerBuilder.instance.libraryManager.tempDir;
                } else {
                    videoName = PathMaker.getVideoName(this.source);
                    videoPath = new File(this.source.substring(0, this.source.lastIndexOf("/") + 1));
                }

                // maxCountが小さすぎると過去コメントが保存されないケースがあるので水増し
                var maxCount: Number = (FlexGlobals.topLevelApplication as NNDD).getSaveCommentMaxCount();
                if (maxCount < 10000) {
                    maxCount = 10000;
                }

                // 過去コメント取得時のコメント更新は一律で追記。
                renewDownloadManagerForOldComment.renewForCommentOnly(
                    UserManager.instance.user,
                    UserManager.instance.password,
                    videoId,
                    videoName,
                    videoPath,
                    true,
                    date,
                    maxCount,
                    FlexGlobals.topLevelApplication.getUseOldTypeCommentGet()
                );

            }

        }

        /**
         *
         * @param event
         *
         */
        protected function byteloadedChangedEventHandler(event: Event): void {
            trace(event.type);
            if (videoInfoView.isResizePlayerEachPlay) {
                resizePlayerJustVideoSize(videoPlayer.nowRatio);
            } else {
                resizePlayerJustVideoSize();
            }
        }

        /**
         *
         * @param event
         *
         */
        protected function osmfCurrentTimeChangeEventHandler(event: TimeEvent): void {
//			trace(event.type + ", time:" + event.time);
//			if(event.time < 0){
//				return;
//			}
//			if(videoInfoView.isResizePlayerEachPlay){
//				resizePlayerJustVideoSize(videoPlayer.nowRatio);
//			}else{
//				resizePlayerJustVideoSize();
//			}
        }

        /**
         *
         * @param videoId
         * @return
         *
         */
        public function myListGroupUpdate(videoId: String): void {

            myListLoader = new MyListLoader();
            myListLoader.addEventListener(MyListLoader.GET_MYLISTGROUP_SUCCESS, function (event: Event): void {
                var myLists: Array = myListLoader.getMyLists();

                if (myLists.length > 0) {
                    var myListNames: Array = new Array();
                    var myListIds: Array = new Array();

                    for each(var array: Array in myLists) {
                        myListNames.push(array[0]);
                        myListIds.push(array[1]);
                    }

                    videoInfoView.setMyLists(myListNames, myListIds);
                }
                myListLoader.close();
            });
            myListLoader.addEventListener(MyListLoader.GET_MYLISTGROUP_FAILURE, function (event: ErrorEvent): void {
                myListLoader.close();
                logManager.addLog("マイリスト一覧の取得に失敗:" + event + ":" + event.text);
            });
            myListLoader.getMyListGroup(videoId);

        }


        /**
         *
         * @param event
         *
         */
        private function mediaPlayerStateChanged(event: MediaPlayerStateChangeEvent): void {
            if (videoDisplay != null && !isPlayerClosing) {
                if (event.state != MediaPlayerState.BUFFERING) {
                    videoPlayer.label_downloadStatus.text = "";
                    videoDisplay.removeEventListener(
                        MediaPlayerStateChangeEvent.MEDIA_PLAYER_STATE_CHANGE,
                        mediaPlayerStateChanged
                    );
                    if (commentTimer != null && !commentTimer.running) {
                        time = (new Date).time;
                        commentTimer.start();
                    }
                }
            } else {
                (event.currentTarget as PatchedVideoDisplay).stop();
                (event.currentTarget as PatchedVideoDisplay).removeEventListener(
                    MediaPlayerStateChangeEvent.MEDIA_PLAYER_STATE_CHANGE,
                    mediaPlayerStateChanged
                );
                destructor();
            }
        }

        /**
         *
         * @param event
         *
         */
        private function convertCompleteHandler(event: Event): void {

            isSwfConverting = false;

            if (loader != null && !isPlayerClosing) {

                mc = LoaderInfo(event.currentTarget).loader.content as MovieClip;
                swfFrameRate = LoaderInfo(event.currentTarget).loader.contentLoaderInfo.frameRate;
                setVolume(videoPlayer.videoController.slider_volume.value);

                if (videoInfoView.isResizePlayerEachPlay) {
                    resizePlayerJustVideoSize(videoPlayer.nowRatio);
                } else {
                    resizePlayerJustVideoSize();
                }

                videoPlayer.label_downloadStatus.text = "";

                commentTimer.start();
                time = (new Date).time;

            } else {

                if (mc != null) {
                    mc.stop();
                }
                destructor();
                if (event.currentTarget as LoaderInfo) {
                    LoaderInfo(event.currentTarget).loader.unloadAndStop(true);
                }

            }

            LoaderInfo(event.currentTarget).loader.removeEventListener(Event.COMPLETE, convertCompleteHandler);

        }

        /**
         * プレイリストを更新し、動画の再生を開始します。
         *
         * @param videoPath
         * @param windowType
         * @param comments
         * @param ngList
         * @param playList プレイリスト（m3u形式）
         * @param videoNameList プレイリストにニコ動のURLが入る場合に変わりに表示させたいプレイリストのタイトル
         * @param playingIndex 再生開始インデックス
         * @param autoPlay 自動再生
         * @param isStreamingPlay ストリーミング再生かどうか
         * @param downLoadedURL ダウンロード済URL
         * @return
         *
         */
        private function initWithPlayList(
            videoPath: String,
            windowType: int,
            comments: Comments,
            playList: Array,
            videoNameList: Array,
            playListName: String,
            playingIndex: int,
            autoPlay: Boolean = false,
            isStreamingPlay: Boolean = false,
            downLoadedURL: String = null,
            videoTitle: String = null
        ): void {

//			this.streamingRetryCount = 0;

            this.playingIndex = playingIndex;
            this.isPlayListingPlay = true;
            var videoNameArray: Array = videoNameList;
            if (videoNameArray == null) {
                videoNameArray = new Array();
                for (var i: int; i < playList.length; i++) {
                    var url: String = playList[i];
                    videoNameArray.push(url.substring(url.lastIndexOf("/") + 1));
                }
            }

            if (downLoadedURL == null) {
                downLoadedURL = videoPath;
            }

            this.videoInfoView.resetPlayList();
            this.videoInfoView.setPlayList(playList, videoNameArray, playListName);

            trace("\t" + playList);

            this.init(
                videoPath,
                windowType,
                comments,
                PathMaker.createThmbInfoPathByVideoPath(downLoadedURL),
                autoPlay,
                isStreamingPlay,
                videoTitle,
                true,
                LibraryUtil.getVideoKey(videoTitle)
            );
        }

        /**
         * VideoPlayerのプレイリストが選択された際に呼ばれるメソッドです。
         *
         * @param url
         * @param index
         * @return
         *
         */
        public function initForVideoPlayer(url: String, index: int): void {
            playMovie(
                url,
                this.videoInfoView.playList,
                index,
                PathMaker.getVideoName(this.videoInfoView.getPlayListUrl(index))
            );
        }

        /**
         *
         * @param isSmoothing
         *
         */
        public function setVideoSmoothing(isSmoothing: Boolean): void {
            if (this.videoDisplay === null || this.videoDisplay.videoSurfaceObject === null) {
                return;
            }

            // スムージングしない
            if (isSmoothing === false) {
                videoDisplay.videoSurfaceObject.smoothing = false;
                return;
            }

            if (videoDisplay.videoSurfaceObject.videoWidth !== videoDisplay.videoSurfaceObject.width) {
                // 動画がピクセル等倍以外で表示されている場合
                videoDisplay.videoSurfaceObject.smoothing = true;
                return;
            }

            // 動画がピクセル等倍で表示されている場合
            if (videoInfoView.isSmoothingOnlyNotPixelIdenticalDimensions) {
                // ピクセル等倍のときはスムージングしない設定の場合
                videoDisplay.videoSurfaceObject.smoothing = false;
                return;
            }

            // ピクセル等倍のときもスムージングする
            videoDisplay.videoSurfaceObject.smoothing = true;
        }

        /**
         *
         * @param value 0-3 default=2
         *
         */
        public function setPlayerQuality(value: int): void {
            if (this.videoPlayer.stage === null) {
                return;
            }

            var qualityStr: String = StageQuality.HIGH;
            switch (value) {
                case 0:
                    qualityStr = StageQuality.LOW;
                    break;
                case 1:
                    qualityStr = StageQuality.MEDIUM;
                    break;
                case 2:
                    qualityStr = StageQuality.HIGH;
                    break;
                case 3:
                    qualityStr = StageQuality.BEST;
                    break;
                default:
                    qualityStr = StageQuality.HIGH;
            }

            this.videoPlayer.stage.quality = qualityStr;
        }

        /**
         *
         * @param value 0-300 default=0
         *
         */
        public function setBufferingLength(value: int): void {
            HLSSettings.maxBufferLength = value;
            HLSSettings.maxBackBufferLength = value;
        }

        /**
         *
         * @param bool
         *
         */
        public function isUseOldVersionVideoSize(bool: Boolean): void {
            this._useOldVersionVideoSize = bool;
        }


        /**
         * videoDisplayの大きさを動画にあわせ、同時にウィンドウの大きさを変更します。
         * フルスクリーン時に呼ばれても何もしません。
         */
        public function resizePlayerJustVideoSize(windowSizeRatio: Number = -1): void {

            try {
                var ratio: Number = 1;
                if (windowSizeRatio != -1) {
                    ratio = windowSizeRatio;
                }

                //再生窓の既定の大きさ
                var videoWindowHeight: int;
                var videoWindowWidth: int;

                if (_useOldVersionVideoSize) {
                    videoWindowHeight = PlayerController.NICO_VIDEO_WINDOW_HEIGHT * ratio;
                    videoWindowWidth = PlayerController.NICO_VIDEO_WINDOW_WIDTH * ratio;
                } else {
                    videoWindowHeight = PlayerController.NICO_VIDEO_NEW_WINDOW_HEIGHT * ratio;
                    videoWindowWidth = PlayerController.NICO_VIDEO_NEW_WINDOW_WIDTH_WIDE_MODE * ratio;
                }

                //ニコ割窓の既定の大きさ
                var nicowariWindowHeight: int = PlayerController.NICO_WARI_HEIGHT * ratio;
                var nicowariWindowWidth: int = PlayerController.NICO_WARI_WIDTH * ratio;

                //InfoViewのプレイリストの項目を選択
                if (isPlayListingPlay) {
                    if (this.videoInfoView != null) {
                        videoInfoView.showPlayingTitle(playingIndex);
                    }
                }

                //フルスクリーンではないか？
                if (this.videoPlayer.stage != null && this.videoPlayer.stage.displayState !=
                    StageDisplayState.FULL_SCREEN_INTERACTIVE) {
                    //再生ごとのリサイズが有効か？ 有効でなくてもレートが指定されているか？
                    if (this.videoInfoView.isResizePlayerEachPlay || windowSizeRatio != -1) {

                        if (this.windowType == PlayerController.WINDOW_TYPE_FLV && this.videoDisplay != null &&
                            this.videoDisplay.videoSurfaceObject != null) {
                            //FLV再生か？

                            // スムージングを設定
                            this.setVideoSmoothing(videoInfoView.isSmoothing);

                            if (this.videoInfoView.selectedResizeType == VideoInfoView.RESIZE_TYPE_NICO &&
                                this.videoDisplay.videoSurfaceObject.videoHeight > 0) {

                                //動画の大きさがニコ動の表示窓より小さいとき && ウィンドウの大きさを動画に合わせる (動画の高さが０の時は読み込み終わっていないのでスキップ)
                                var isWideVideo: Boolean = false;
                                if (WIDE_MODE_ASPECT_RATIO < Number(this.videoDisplay.videoSurfaceObject.videoWidth) /
                                    Number(this.videoDisplay.videoSurfaceObject.videoHeight)) {
                                    // この動画は16:9だ
                                    isWideVideo = true;
                                    trace("enable 16:9 mode");
                                }


                                if (_useOldVersionVideoSize) {
                                    videoWindowHeight = PlayerController.NICO_VIDEO_WINDOW_HEIGHT * ratio;
                                    if (this.videoInfoView.isEnableWideMode && isWideVideo) {
                                        videoWindowWidth = (PlayerController.NICO_VIDEO_WINDOW_WIDTH_WIDE_MODE +
                                                            PlayerController.NICO_VIDEO_PADDING * 2) * ratio;
                                    } else {
                                        videoWindowWidth = (PlayerController.NICO_VIDEO_WINDOW_WIDTH +
                                                            PlayerController.NICO_VIDEO_PADDING * 2) * ratio;
                                    }
                                } else {
                                    videoWindowHeight = PlayerController.NICO_VIDEO_NEW_WINDOW_HEIGHT * ratio;
                                    if (this.videoInfoView.isEnableWideMode && isWideVideo) {
                                        videoWindowWidth = (PlayerController.NICO_VIDEO_NEW_WINDOW_WIDTH_WIDE_MODE +
                                                            PlayerController.NICO_VIDEO_PADDING * 2) * ratio;
                                    } else {
                                        videoWindowWidth = (PlayerController.NICO_VIDEO_NEW_WINDOW_WIDTH +
                                                            PlayerController.NICO_VIDEO_PADDING * 2) * ratio;
                                    }
                                }

                                //動画そのものはセンターに表示
                                this.videoDisplay.setConstraintValue("bottom", 0);
                                this.videoDisplay.setConstraintValue("left", NICO_VIDEO_PADDING);
                                this.videoDisplay.setConstraintValue("right", NICO_VIDEO_PADDING);
                                this.videoDisplay.setConstraintValue("top", 0);

                                trace(videoDisplay.width + "," + videoDisplay.height);

                                logManager.addLog("オリジナルの動画サイズ:" + this.videoDisplay.videoSurfaceObject.videoWidth +
                                                  " x " + this.videoDisplay.videoSurfaceObject.videoHeight);

                                if (videoDisplay.hasEventListener(LoadEvent.BYTES_LOADED_CHANGE)) {
                                    //init後の初回の大きさ合わせが出来れば良いので以降のシークでは呼ばれないようにする
                                    videoDisplay.removeEventListener(
                                        LoadEvent.BYTES_LOADED_CHANGE,
                                        byteloadedChangedEventHandler
                                    );
//									resizePlayerJustVideoSize(windowSizeRatio);
                                }
                                if (videoDisplay.hasEventListener(TimeEvent.CURRENT_TIME_CHANGE)) {
                                    videoDisplay.removeEventListener(
                                        TimeEvent.CURRENT_TIME_CHANGE,
                                        osmfCurrentTimeChangeEventHandler
                                    );
                                }

                            } else if (this.videoInfoView.selectedResizeType == VideoInfoView.RESIZE_TYPE_VIDEO &&
                                       this.videoDisplay.videoSurfaceObject.videoHeight > 0) {

                                //動画の大きさにウィンドウの大きさを合わせるとき(videoHeightが0の時は動画がまだ読み込まれていないのでスキップ)

                                videoWindowHeight = (this.videoDisplay.videoSurfaceObject.videoHeight * ratio) +
                                                    PlayerController.NICO_VIDEO_PADDING * 2;
                                videoWindowWidth = (this.videoDisplay.videoSurfaceObject.videoWidth * ratio) +
                                                   PlayerController.NICO_VIDEO_PADDING * 2;

                                this.videoDisplay.setConstraintValue("bottom", NICO_VIDEO_PADDING);
                                this.videoDisplay.setConstraintValue("left", NICO_VIDEO_PADDING);
                                this.videoDisplay.setConstraintValue("right", NICO_VIDEO_PADDING);
                                this.videoDisplay.setConstraintValue("top", NICO_VIDEO_PADDING);

                                if (videoDisplay.hasEventListener(LoadEvent.BYTES_LOADED_CHANGE)) {
                                    //init後の初回の大きさ合わせが出来れば良いので以降のシークでは呼ばれないようにする
                                    videoDisplay.removeEventListener(
                                        LoadEvent.BYTES_LOADED_CHANGE,
                                        byteloadedChangedEventHandler
                                    );
//									resizePlayerJustVideoSize(windowSizeRatio);
                                }
                                if (videoDisplay.hasEventListener(TimeEvent.CURRENT_TIME_CHANGE)) {
                                    videoDisplay.removeEventListener(
                                        TimeEvent.CURRENT_TIME_CHANGE,
                                        osmfCurrentTimeChangeEventHandler
                                    );
                                }
                            } else {
                                //中断。後で呼ばれる事を期待する。
                                return;
                            }

                        } else if (this.windowType == PlayerController.WINDOW_TYPE_SWF) {
                            //SWF再生か？

                            //SWFの場合は一律でサイズを固定
                            if (_useOldVersionVideoSize) {
                                videoWindowHeight = PlayerController.NICO_VIDEO_WINDOW_HEIGHT * ratio;
                                videoWindowWidth = PlayerController.NICO_VIDEO_WINDOW_WIDTH * ratio;
                            } else {
                                videoWindowHeight = PlayerController.NICO_VIDEO_NEW_WINDOW_HEIGHT * ratio;
                                videoWindowWidth = PlayerController.NICO_VIDEO_NEW_WINDOW_WIDTH * ratio;
                            }

                        }

                        if (videoPlayer.canvas_nicowari.height < 1) {
                            //ニコ割領域が表示されていなければ、その文余分に高さを設定
                            videoWindowHeight += (NICO_WARI_HEIGHT + NICO_VIDEO_PADDING);
                        } else {
                            videoWindowHeight += NICO_VIDEO_PADDING;
                        }

                        this.videoPlayer.nativeWindow.height +=
                            int(videoWindowHeight - this.videoPlayer.canvas_video_back.height);
                        this.videoPlayer.nativeWindow.width +=
                            int(videoWindowWidth - this.videoPlayer.canvas_video_back.width);

                        if (this.videoDisplay != null) {
                            logManager.addLog("表示中の動画サイズ:" + this.videoDisplay.width + " x " +
                                              this.videoDisplay.height);
                        }

//						(this.videoPlayer as Window).validateDisplayList();
//						(this.videoPlayer as Window).validateNow();

                        //ネイティブなウィンドウの大きさと、ウィンドウ内部の利用可能な領域の大きさの差
//						var diffH:int = this.videoPlayer.nativeWindow.height - this.videoPlayer.stage.stageHeight;
//						var diffW:int = this.videoPlayer.nativeWindow.width - this.videoPlayer.stage.stageWidth;

                    } else {
                        // ウィンドウの大きさ調整が無効
                        if (this.windowType == PlayerController.WINDOW_TYPE_FLV && this.videoDisplay != null &&
                            this.videoDisplay.videoSurfaceObject != null) {
                            //FLV再生か？

                            // スムージングを設定
                            this.setVideoSmoothing(videoInfoView.isSmoothing);

                            if (videoDisplay.hasEventListener(LoadEvent.BYTES_LOADED_CHANGE)) {
                                //init後の初回の大きさ合わせが出来れば良いので以降のシークでは呼ばれないようにする
                                videoDisplay.removeEventListener(
                                    LoadEvent.BYTES_LOADED_CHANGE,
                                    byteloadedChangedEventHandler
                                );
                            }
                            if (videoDisplay.hasEventListener(TimeEvent.CURRENT_TIME_CHANGE)) {
                                videoDisplay.removeEventListener(
                                    TimeEvent.CURRENT_TIME_CHANGE,
                                    osmfCurrentTimeChangeEventHandler
                                );
                            }

                        }

                    }

                } else {
                    if (PlayerController.WINDOW_TYPE_FLV == this.windowType) {
                        if (videoInfoView != null) {
                            this.setVideoSmoothing(videoInfoView.isSmoothing);
                        }
                    }
                }

                updateVideoStatus();

            } catch (error: Error) {	//ウィンドウが閉じられた後に呼ばれるとエラー。停止処理を行う。
                trace(error.getStackTrace());
                logManager.addLog("ウィンドウサイズの調整に失敗:" + error + ", " + error.getStackTrace());
                stop();
                destructor();
            }
        }


        /**
         * 登録されている動画に対して再生を要求します。
         * 動画が再生中で、一時停止が可能であれば、一時停止を要求します。
         * @return
         */
        public function switchPlayer(): void {
            try {
                videoPlayer.canvas_video_back.setFocus();

                var newComments: Comments = null;
                videoPlayer.canvas_video.toolTip = null;
                if (this.windowType == PlayerController.WINDOW_TYPE_FLV) {
                    if (videoDisplay != null && videoDisplay.playing) {
                        videoPlayer.videoController.button_play.setStyle("icon", icon_Play);
                        videoPlayer.videoController_under.button_play.setStyle("icon", icon_Play);
                        this.commentTimer.stop();
                        this.commentTimer.reset();
                        videoDisplay.pause();
                        pausing = true;
                    } else {
                        videoPlayer.videoController.button_play.setStyle("icon", icon_Pause);
                        videoPlayer.videoController_under.button_play.setStyle("icon", icon_Pause);
                        if (pausing) {
                            this.videoPlayer.videoController.slider_timeline.enabled = true;
                            this.videoPlayer.videoController_under.slider_timeline.enabled = true;
                            this.videoDisplay.play();
                            this.time = (new Date).time;
                            this.commentTimer.start();
                        } else {
                            this.videoPlayer.videoController.slider_timeline.enabled = true;
                            this.videoPlayer.videoController_under.slider_timeline.enabled = true;
                            this.playMovie(source, null, -1, this.downLoadedURL);
                        }
                        pausing = false;
                    }
                } else if (this.windowType == PlayerController.WINDOW_TYPE_SWF) {
                    if (isMovieClipPlaying) {
                        videoPlayer.videoController.button_play.setStyle("icon", icon_Play);
                        videoPlayer.videoController_under.button_play.setStyle("icon", icon_Play);
                        this.commentTimer.stop();
                        this.commentTimer.reset();
                        mc.stop();
                        isMovieClipPlaying = false;
                        pausing = true;
                    } else {
                        videoPlayer.videoController.button_play.setStyle("icon", icon_Pause);
                        videoPlayer.videoController_under.button_play.setStyle("icon", icon_Pause);
                        if (pausing) {
                            this.videoPlayer.videoController.slider_timeline.enabled = true;
                            this.videoPlayer.videoController_under.slider_timeline.enabled = true;
                            mc.play();
                            isMovieClipPlaying = true;
                            this.time = (new Date).time;
                            this.commentTimer.start();
                        } else {
                            this.videoPlayer.canvas_video.removeAllChildren();
                            this.videoPlayer.videoController.slider_timeline.enabled = true;
                            this.videoPlayer.videoController_under.slider_timeline.enabled = true;
                            this.playMovie(source, null, -1, this.downLoadedURL);

                        }
                        pausing = false;
                    }
                } else {
                    if (this.videoPlayer != null && this.videoPlayer.title != null) {
                        this.playMovie(this.videoPlayer.title);
                    }
                }

            } catch (error: Error) {
                trace(error.getStackTrace());
                logManager.addLog("再生に失敗しました:" + error + ":" + error.getStackTrace());
            }

        }

        /**
         * 動画を再生する.
         * 既に動画が再生中や再生可能でない状態では何もしないことを保証する.
         */
        public function play(): void {
            var callback: Function;
            // 再生可能かどうか判断
            switch (this.windowType) {
                case WINDOW_TYPE_FLV:
                    if (this.videoDisplay === null || this.videoDisplay.playing) {
                        return;
                    }
                    callback = this.videoDisplay.play;
                    break;
                case WINDOW_TYPE_SWF:
                    if (!this.isMovieClipPlaying) {
                        return;
                    }
                    callback = function (): void {
                        mc.play();
                        isMovieClipPlaying = true;
                    };
                    break;
                default:
                    return;
            }

            this.videoPlayer.videoController.button_play.setStyle("icon", this.icon_Pause);
            this.videoPlayer.videoController_under.button_play.setStyle("icon", this.icon_Pause);
            this.videoPlayer.videoController.slider_timeline.enabled = true;
            this.videoPlayer.videoController_under.slider_timeline.enabled = true;
            callback();
            this.time = (new Date).time;
            this.commentTimer.start();
            this.pausing = false;
        }

        /**
         * 動画を一時停止する.
         * PlayerControllerの状態にも反映する.
         */
        public function pause(): void {
            // 状態を一時停止に寄せる
            this.pausing = true;
            this.videoPlayer.videoController.button_play.setStyle("icon", this.icon_Play);
            this.videoPlayer.videoController_under.button_play.setStyle("icon", this.icon_Play);
            this.commentTimer.stop();
            this.commentTimer.reset();

            var callback: Function;
            // 再生中かどうか判断
            switch (this.windowType) {
                case WINDOW_TYPE_FLV:
                    if (this.videoDisplay === null || !this.videoDisplay.playing) {
                        return;
                    }
                    callback = this.videoDisplay.pause;
                    break;
                case WINDOW_TYPE_SWF:
                    if (!this.isMovieClipPlaying) {
                        return;
                    }
                    callback = function (): void {
                        mc.stop();
                        isMovieClipPlaying = false;
                    };
                    break;
                default:
                    return;
            }

            callback();
        }

        /**
         * 動画が現在再生中かどうかを返す.
         */
        public function get isPlaying(): Boolean {
            switch (this.windowType) {
                case WINDOW_TYPE_FLV:
                    return this.videoDisplay !== null && this.videoDisplay.playing;
                case WINDOW_TYPE_SWF:
                    return this.mc !== null && this.mc.isPlaying;
                default:
                    return false;
            }
        }


        /**
         * 再生している動画を停止させます。
         * 停止ボタン押しても呼ばれないので注意(VideoPlayer.stop()が呼ばれ, その内部でgoToTop()が呼ばれている)
         * @return
         *
         * TODO: stop()とdestructor()がどちらもcleanupを実施していて名前が役割を説明していない
         */
        public function stop(): void {
            try {

                pausing = false;

                if (videoInfoView.isShowAlwaysNicowariArea) {
                    videoPlayer.showNicowariArea();
                } else {
                    videoPlayer.hideNicowariArea();
                }

                if (videoPlayer != null && videoPlayer.label_downloadStatus != null) {
                    videoPlayer.canvas_video_back.setFocus();
                    videoPlayer.label_downloadStatus.text = "";
                    videoPlayer.canvas_video.toolTip = "ここに動画ファイルをドロップすると動画を再生できます。";
                }

                if (this.movieEndTimer != null) {
                    this.movieEndTimer.stop();
                    this.movieEndTimer = null;
                }

                if (renewDownloadManager != null) {
                    try {
                        renewDownloadManager.close();
                        renewDownloadManager = null;
                        logManager.addLog("再生前の情報更新をキャンセルしました。");
                    } catch (error: Error) {
                        trace(error);
                    }
                } else {

                    this.videoPlayer.videoController.button_play.enabled = true;
                    this.videoPlayer.videoController_under.button_play.enabled = true;
                    videoPlayer.videoController.button_play.setStyle("icon", icon_Play);
                    videoPlayer.videoController_under.button_play.setStyle("icon", icon_Play);

                    this.videoPlayer.videoController_under.slider_timeline.value = 0;
                    this.videoPlayer.videoController.slider_timeline.value = 0;

                    this.commentTimerVpos = 0;
                    this.commentTimer.stop();
                    this.commentTimer.reset();
                    this.commentManager.removeAll();

                    //再生関係のコンポーネントを掃除
                    this.destructor();

                    //終了時にニコ割が鳴っていたら止める。
                    videoPlayer.canvas_nicowari.removeAllChildren();
                    if (nicowariMC != null) {
                        this.pauseByNicowari(true);
                    }

                }

            } catch (error: Error) {
                trace(error.getStackTrace());
                logManager.addLog("停止中にエラーが発生しました:" + error + ":" + error.getStackTrace());
            }

        }


        /**
         * 動画の読み込みを中止せずにシーク場所を先頭に戻します。
         * 1箇所でしか呼ばれていない
         *
         * TODO: 単にポーズして先頭にシークするのと何が違う？ニコ割関連？
         */
        public function goToTop(): void {
            try {

                pausing = false;

                if (videoInfoView.isShowAlwaysNicowariArea) {
                    videoPlayer.showNicowariArea();
                } else {
                    videoPlayer.hideNicowariArea();
                }

                if (videoPlayer != null && videoPlayer.label_downloadStatus != null) {
                    videoPlayer.canvas_video_back.setFocus();
                    videoPlayer.label_downloadStatus.text = "";
                    videoPlayer.canvas_video.toolTip = "ここに動画ファイルをドロップすると動画を再生できます。";
                }

                if (this.movieEndTimer != null) {
                    this.movieEndTimer.stop();
                    this.movieEndTimer = null;
                }

                if (renewDownloadManager != null) {
                    try {
                        renewDownloadManager.close();
                        renewDownloadManager = null;
                        logManager.addLog("再生前の情報更新をキャンセルしました。");
                    } catch (error: Error) {
                        trace(error);
                    }
                } else {

                    this.videoPlayer.videoController.button_play.enabled = true;
                    this.videoPlayer.videoController_under.button_play.enabled = true;
                    videoPlayer.videoController.button_play.setStyle("icon", icon_Play);
                    videoPlayer.videoController_under.button_play.setStyle("icon", icon_Play);

                    this.videoPlayer.videoController_under.slider_timeline.value = 0;
                    this.videoPlayer.videoController.slider_timeline.value = 0;

                    this.commentTimerVpos = 0;
                    this.commentTimer.stop();
                    this.commentTimer.reset();

                    // TODO: 何で this.pausing を使っていない？
                    var playing: Boolean = false;
                    if (this.windowType == PlayerController.WINDOW_TYPE_FLV) {
                        if (videoDisplay != null && videoDisplay.playing) {
                            playing = true;
                        }
                    } else if (this.windowType == PlayerController.WINDOW_TYPE_SWF) {
                        if (isMovieClipPlaying) {
                            playing = true;
                        }
                    }

                    if (playing) {
                        this.switchPlayer();
                    }
                    this.seek(0);


                    //終了時にニコ割が鳴っていたら止める。
                    videoPlayer.canvas_nicowari.removeAllChildren();
                    if (nicowariMC != null) {
                        this.pauseByNicowari(true);
                    }

                }

            } catch (error: Error) {
                trace(error.getStackTrace());
                logManager.addLog("停止中にエラーが発生しました:" + error + ":" + error.getStackTrace());
            }
        }

        /**
         * VideoDisplayに関連するリスナをまとめて登録します。
         * @param videoDisplay
         *
         */
        private function addVideoDisplayEventListeners(videoDisplay: PatchedVideoDisplay): void {
            videoDisplay.addEventListener(TimeEvent.CURRENT_TIME_CHANGE, currentTimeChangeEventHandler);
            videoDisplay.addEventListener(TimeEvent.DURATION_CHANGE, durationChangeEventHandler);
            videoDisplay.addEventListener(TimeEvent.COMPLETE, videoDisplayCompleteHandler);
        }

        /**
         * VideoDisplayに関連するリスナをまとめて削除します。
         * @param videoDisplay
         *
         */
        private function removeVideoDisplayEventListeners(videoDisplay: PatchedVideoDisplay): void {
            if (videoDisplay.hasEventListener(TimeEvent.CURRENT_TIME_CHANGE)) {
                videoDisplay.removeEventListener(TimeEvent.CURRENT_TIME_CHANGE, currentTimeChangeEventHandler);
            }
            if (videoDisplay.hasEventListener(TimeEvent.DURATION_CHANGE)) {
                videoDisplay.removeEventListener(TimeEvent.DURATION_CHANGE, durationChangeEventHandler);
            }
            if (videoDisplay.hasEventListener(VideoEvent.COMPLETE)) {
                videoDisplay.removeEventListener(TimeEvent.COMPLETE, videoDisplayCompleteHandler);
            }
        }

        /**
         *
         * @param event
         *
         */
        private function durationChangeEventHandler(event: TimeEvent): void {
//			if(videoInfoView.isResizePlayerEachPlay){
//				resizePlayerJustVideoSize(videoPlayer.nowRatio);
//			}else{
//				resizePlayerJustVideoSize();
//			}
        }

        /**
         *
         * @param loader
         *
         */
//		private function removeMovieClipEventHandlers(loader:Loader):void{
//			if(loader.hasEventListener(Event.COMPLETE)){
//				loader.removeEventListener(Event.COMPLETE, convertCompleteHandler);
//			}
//		}

        /**
         * ストリーミングのダウンロード状況を百分率で返します。
         * @return
         *
         */
        public function getStreamingProgress(): Number {
            if (!isStreamingPlay) {
                return 100;
            }
            if (videoDisplay !== null && videoDisplay.bytesTotal > 0) {
                return videoDisplay.bytesLoaded * 100 / videoDisplay.bytesTotal;
            }
            if (loader != null && loader.contentLoaderInfo != null) {
                return loader.contentLoaderInfo.bytesLoaded * 100 / loader.contentLoaderInfo.bytesTotal;
            }

            return 0;
        }


        /**
         * ストリーミングのダウンロード速度をMB/sで返します。
         * @return
         *
         */
        public function getStreamingSpeed(interval: Number): Number {

            // timerからintervalごとに呼ばれる

            if (!this.isStreamingPlay) {
                return 0;
            }

            var value: Number = 0;
            if (videoDisplay != null) {
                value = videoDisplay.bytesLoaded - this.lastLoadedBytes;
                this.lastLoadedBytes = videoDisplay.bytesLoaded;
            } else if (loader != null && loader.contentLoaderInfo != null) {
                value = loader.contentLoaderInfo.bytesLoaded - this.lastLoadedBytes;
                this.lastLoadedBytes = loader.contentLoaderInfo.bytesLoaded;
            } else {
                return value;
            }

            if (!this.isHLS) {
                //MBに直す
                value /= 1048576;
            }

            trace("StreamingProgress: " + value + "MB");

            // MB/sに直す
            value /= interval / 1000;

            return value;
        }

        /**
         *
         * @return
         *
         */
        public function get bytesLoaded(): Number {
            if (this.videoDisplay != null) {
                // bytes単位に直す (DynamicStreamingResouce使用時はMB単位がデフォルトのため)
                return this.videoDisplay.bytesLoaded * (this.isHLS ? 1048576 : 1);
            }
            if (this.loader != null && this.loader.contentLoaderInfo != null) {
                return this.loader.contentLoaderInfo.bytesLoaded;
            }

            return 0;
        }

        /**
         *
         * @param event
         *
         */
        private function streamingProgressHandler(event: TimerEvent): void {
            // ストリーミング再生でない
            if (!this.isStreamingPlay) {
                if (streamingProgressTimer !== null) {
                    streamingProgressTimer.stop();
                }

                return;
            }

            var value: Number = getStreamingProgress();
            var speed: Number = getStreamingSpeed((event.target as Timer).delay);

            // ストリーミング進捗が100%未満
            if (value < 100) {
                var formatter: NumberFormatter = new NumberFormatter();
                formatter.precision = 2;
                var str: String = formatter.format(speed) + "MB/s";

                this.videoPlayer.label_playSourceStatus.text =
                    "Streaming:" + formatter.format(value) + "% (" + str + ")";

                return;
            }

            // ストリーミング進捗100%
            this.videoPlayer.label_playSourceStatus.text = "Streaming:100%";
            videoPlayer.videoController.resetStatusAlpha();
            if (streamingProgressTimer !== null) {
                streamingProgressTimer.stop();
            }

            // ある程度以上データが読めていれば完了
            if (this.bytesLoaded > 16) {
                this.streamingRetryCount = 0;
                return;
            }

            // 100%読み込みしたはずなのに読み込み済みバイト数が異常に少ない
            // 接続リトライを試行する
            var maxCount: int = 1;
            var confValue: String = ConfigManager.getInstance().getItem("streamingRetryMaxCount");
            if (confValue == null) {
                ConfigManager.getInstance().removeItem("streamingRetryMaxCount");
                ConfigManager.getInstance().setItem("streamingRetryMaxCount", maxCount);
            } else {
                maxCount = int(confValue);
            }

            // 最大許容リトライ回数以下ならば再生し直す
            if (this.streamingRetryCount <= maxCount) {
                // 再生し直す
                this.streamingRetryCount++;
                var timeStr: String = String(int(10000 * this.streamingRetryCount / 1000));
                stop();
                logManager.addLog("ニコ動へのアクセスの再試行(動画読み込みに失敗:読み込み済みバイト数:" + this.bytesLoaded + ")");
                videoPlayer.label_downloadStatus.text =
                    "動画の読み込みに失敗したため、再試行します。(" + timeStr + "秒後、" + this.streamingRetryCount + "回目 )";

                if (nicoVideoAccessRetryTimer != null) {
                    nicoVideoAccessRetryTimer.stop();
                    nicoVideoAccessRetryTimer = null;
                }
                nicoVideoAccessRetryTimer = new Timer(10000 * this.streamingRetryCount, 1);
                nicoVideoAccessRetryTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function (event: Event): void {
                    (event.currentTarget as Timer).stop();
                    // TODO: DMCサーバ接続時のリトライ方法修正
                    switchPlayer();
                });
                nicoVideoAccessRetryTimer.start();

                return;
            }

            // 最大試行回数を超えたのでエラー終了
            stop();
            logManager.addLog("動画読み込みに失敗:読み込み済みバイト数:" + this.bytesLoaded);
            videoPlayer.label_downloadStatus.text = "動画の読み込みに失敗しました。(動画が正しく読み込めませんでした。)";
        }

        /**
         * 動画の再生中に呼ばれるハンドラです。
         * @param evt
         *
         */
        private function currentTimeChangeEventHandler(event: TimeEvent = null): void {
            try {
                var allSec: String = "00", allMin: String = "0";
                var nowSec: String = "00", nowMin: String = "0";

                this.commentTimerVpos = event.time * 1000;

                nowSec = String(int(this.videoDisplay.currentTime % 60));
                nowMin = String(int(this.videoDisplay.currentTime / 60));

                allSec = String(int(this.videoDisplay.duration % 60));
                allMin = String(int(this.videoDisplay.duration / 60));

                if (nowSec.length == 1) {
                    nowSec = "0" + nowSec;
                }
                if (allSec.length == 1) {
                    allSec = "0" + allSec;
                }

                videoPlayer.videoController_under.slider_timeline.enabled = true;
                videoPlayer.videoController_under.slider_timeline.minimum = 0;
                videoPlayer.videoController_under.slider_timeline.maximum = videoDisplay.duration;
                if (!this.sliderChanging) {

                    this.videoPlayer.videoController.slider_timeline.maximum = videoDisplay.duration;
                    this.videoPlayer.videoController_under.slider_timeline.maximum = videoDisplay.duration;
                    videoPlayer.videoController_under.slider_timeline.value = videoDisplay.currentTime;

                }
                videoPlayer.videoController_under.label_time.text = nowMin + ":" + nowSec + "/" + allMin + ":" + allSec;
                videoPlayer.videoController_under.slider_timeline.enabled = true;

                videoPlayer.videoController.slider_timeline.enabled = true;
                videoPlayer.videoController.slider_timeline.minimum = 0;
                videoPlayer.videoController.slider_timeline.maximum = videoDisplay.duration;
                if (!this.sliderChanging) {
                    videoPlayer.videoController.slider_timeline.value = videoDisplay.currentTime;
                }
                videoPlayer.videoController.label_time.text = nowMin + ":" + nowSec + "/" + allMin + ":" + allSec;
                videoPlayer.videoController.slider_timeline.enabled = true;
            } catch (error: Error) {
                PatchedVideoDisplay(event.currentTarget).stop();
                trace(error.getStackTrace());
            }
        }

        /**
         * 動画の再生が終了したときに呼ばれるハンドラです。
         * @param evt
         *
         */
        private function videoDisplayCompleteHandler(evt: TimeEvent = null): void {

            if (movieEndTimer != null) {
                movieEndTimer.stop();
                movieEndTimer = null;
            }
            //残っているコメントが流れ終わるまで待つ
            movieEndTimer = new Timer(2000, 1);
            movieEndTimer.addEventListener(TimerEvent.TIMER_COMPLETE, videoPlayCompleteWaitHandler);
            movieEndTimer.start();

        }

        /**
         *
         *
         */
        private function videoPlayCompleteWaitHandler(event: TimerEvent): void {
            if (!isCounted) {
                //再生回数を加算
                var videoId: String = LibraryUtil.getVideoKey(this.videoPlayer.title);
                if (videoId != null) {
                    addVideoPlayCount(videoId, true);
                }
                isCounted = true;
            }

            logManager.addLog("***動画の停止***");

            if (videoPlayer.isRepeat) {

                /* 動画の1曲リピート */

                if (isPlayListingPlay) {
                    if (isStreamingPlay) {
                        logManager.addLog("***動画のリピート(ストリーミング)***");
                        this.seek(0);
                        this.play();

                        return;
                    }
                    logManager.addLog("***動画のリピート(ローカル)***");
                    this.stop();

                    var url: String = this.videoInfoView.getPlayListUrl(playingIndex);
                    var video: NNDDVideo = libraryManager.isExistByVideoId(LibraryUtil.getVideoKey(url));
                    if (video != null) {
                        url = video.getDecodeUrl();
                    }

                    playMovie(url, this.videoInfoView.playList, playingIndex, this.videoPlayer.title);

                    return;
                }

                if (isStreamingPlay) {
                    logManager.addLog("***動画のリピート(ストリーミング)***");
                    this.seek(0);
                    this.play();

                    return;
                }

                logManager.addLog("***動画のリピート(ローカル)***");
                this.stop();
                this.switchPlayer();

                return;
            }

            /* 動画のリピートは無効 */

            // ストリーミング再生は先頭に戻るだけ
            // それ以外のケースではクリーンアップしてしまってよい
            if (this.isStreamingPlay) {
                this.pause();
                this.seek(0);
            } else {
                this.stop();
            }

            if (isPlayListingPlay) {

                /* プレイリスト再生中 */

                logManager.addLog("***動画の再生(ローカル)***");
                var windowType: int = PlayerController.WINDOW_TYPE_FLV;
                if (playingIndex >= this.videoInfoView.getPlayList().length - 1) {
                    /* プレイリストの先頭に戻る */
                    playingIndex = 0;
                    if (this.videoPlayer.videoInfoView.isRepeatAll()) {
                        var url: String = this.videoInfoView.getPlayListUrl(playingIndex);
                        var video: NNDDVideo = libraryManager.isExistByVideoId(LibraryUtil.getVideoKey(url));
                        if (video != null) {
                            url = video.getDecodeUrl();
                        }

                        playMovie(
                            url,
                            this.videoInfoView.playList,
                            playingIndex,
                            PathMaker.getVideoName(this.videoInfoView.getPlayListUrl(playingIndex))
                        );
                    }
                } else {
                    /* プレイリストの次の項目へ */
                    playingIndex++;

                    var url: String = this.videoInfoView.getPlayListUrl(playingIndex);
                    var video: NNDDVideo = libraryManager.isExistByVideoId(LibraryUtil.getVideoKey(url));
                    if (video != null) {
                        url = video.getDecodeUrl();
                    }

                    playMovie(
                        url,
                        this.videoInfoView.playList,
                        playingIndex,
                        PathMaker.getVideoName(this.videoInfoView.getPlayListUrl(playingIndex))
                    );
                }
            }
        }


        /**
         * SWFの再生が完了したときに呼ばれるハンドラです。
         *
         */
        private function movieClipCompleteHandler(): void {

            this.lastFrame = 0;
            this.lastNicowariFrame = 0;

            if (movieEndTimer != null) {
                movieEndTimer.stop();
                movieEndTimer = null;
            }
            //残っているコメントが流れ終わるまで待つ
            movieEndTimer = new Timer(2000, 1);
            movieEndTimer.addEventListener(TimerEvent.TIMER_COMPLETE, movieClipPlayCompleteWaitHandler);
            movieEndTimer.start();


        }

        /**
         *
         *
         */
        private function movieClipPlayCompleteWaitHandler(event: TimerEvent): void {
            if (!isCounted) {
                //再生回数を加算
                var videoId: String = LibraryUtil.getVideoKey(this.source);
                if (videoId == null) {
                    //ストリーミングのときはタイトルから取る
                    videoId = LibraryUtil.getVideoKey(this.videoPlayer.title);
                }
                if (videoId != null) {
                    addVideoPlayCount(videoId, true);
                }
                isCounted = true;
            }

            logManager.addLog("***動画の停止***");
            this.lastFrame = 0;
            this.lastNicowariFrame = 0;

            if (videoPlayer.isRepeat) {
                if (isPlayListingPlay) {
                    if (isStreamingPlay) {
                        logManager.addLog("***動画のリピート(ストリーミング)***");
                        this.seek(0);
                    } else {
                        logManager.addLog("***動画のリピート(ローカル)***");
                        this.stop();
                        mc.gotoAndStop(0);
                        playMovie(this.videoInfoView.getPlayListUrl(playingIndex),
                                  this.videoInfoView.playList,
                                  playingIndex,
                                  this.videoPlayer.title
                        );
                    }
                } else if (isStreamingPlay) {
                    logManager.addLog("***動画のリピート(ストリーミング)***");
                    this.seek(0);
                } else {
                    logManager.addLog("***動画のリピート(ローカル)***");
                    this.stop();
                    mc.gotoAndStop(0);
                    this.switchPlayer();
                }
            } else {
                this.stop();
                mc.gotoAndStop(0);
                if (isPlayListingPlay) {
                    logManager.addLog("***動画の再生(ローカル)***");
                    var windowType: int = PlayerController.WINDOW_TYPE_FLV;
                    if (playingIndex >= this.videoInfoView.getPlayList().length - 1) {
                        playingIndex = 0;
                        if (this.videoPlayer.videoInfoView.isRepeatAll()) {
                            playMovie(this.videoInfoView.getPlayListUrl(playingIndex),
                                      this.videoInfoView.playList,
                                      playingIndex,
                                      PathMaker.getVideoName(this.videoInfoView.getPlayListUrl(playingIndex))
                            );
                        }
                    } else {
                        playingIndex++;
                        playMovie(this.videoInfoView.getPlayListUrl(playingIndex),
                                  this.videoInfoView.playList,
                                  playingIndex,
                                  PathMaker.getVideoName(this.videoInfoView.getPlayListUrl(playingIndex))
                        );
                    }
                }
            }

            isMovieClipStopping = false;
        }


        /**
         * 指定された動画IDで、ライブラリに存在する動画の再生回数を1加算します
         * @param videoId 再生回数をインクリメントする動画のID
         * @param isSave ライブラリを保存するかどうかです。
         */
        private function addVideoPlayCount(videoId: String, isSave: Boolean): void {
            var nnddVideo: NNDDVideo = libraryManager.isExist(videoId);
            if (nnddVideo != null) {
                nnddVideo.playCount = nnddVideo.playCount + 1;
                libraryManager.update(nnddVideo, isSave);
                trace("再生回数を加算:" + nnddVideo.videoName + "," + nnddVideo.playCount);
            } else {
                //存在しない
                trace("指定された動画は存在せず:" + videoId);
            }
        }

        private function updateVideoStatus(): void {

            var formatter: NumberFormatter = new NumberFormatter();
            formatter.precision = 2;

            if (videoDisplay != null && videoInfoView != null) {
                if (videoDisplay.videoSurfaceObject != null) {
                    videoInfoView.format = videoDisplay.videoSurfaceObject.videoWidth + " × " +
                                           videoDisplay.videoSurfaceObject.videoHeight;
                    videoInfoView.currentWindowSize =
                        videoDisplay.videoSurfaceObject.width + " × " + videoDisplay.videoSurfaceObject.height;
                } else {
                    videoInfoView.format = "-";
                    videoInfoView.currentWindowSize = "-";
                }

                videoInfoView.videoSize = formatter.format((videoDisplay.bytesTotal / (1024 * 1024))) + " MB";
            } else if (loader != null) {
                if (loader.contentLoaderInfo != null) {
                    videoInfoView.format = loader.contentLoaderInfo.width + " × " + loader.contentLoaderInfo.height;
                    videoInfoView.currentWindowSize = loader.width + " × " + loader.height;
                    videoInfoView.videoSize =
                        formatter.format((loader.contentLoaderInfo.bytesTotal / (1024 * 1024))) + " MB";
                }
            }

        }


        /**
         * コメント表示用のタイマーです。
         * swfの再生中はSWFのタイムラインヘッダも更新します。
         *
         * @param event
         *
         */
        private function commentTimerHandler(event: TimerEvent): void {

            if (isPlayerClosing) {
                if (commentTimer != null) {
                    commentTimer.stop();
                    commentTimer.reset();
                }
                return;
            }

            //	音量を反映
            this.setVolume(this.videoPlayer.videoController.slider_volume.value);

            this.updateVideoStatus();

            var nowSec: String = "00", nowMin: String = "0";
            nowSec = String(int(commentTimerVpos / 1000 % 60));
            nowMin = String(int(commentTimerVpos / 1000 / 60));
            if (nowSec.length == 1) {
                nowSec = "0" + nowSec;
            }
            var nowTime: String = nowMin + ":" + nowSec;

            var allSec: String = "00", allMin: String = "0";
            if (this.windowType == PlayerController.WINDOW_TYPE_SWF && this.mc != null) {
                allSec = String(int(mc.totalFrames / swfFrameRate % 60));
                allMin = String(int(mc.totalFrames / swfFrameRate / 60));
            } else if (this.windowType == PlayerController.WINDOW_TYPE_FLV && this.videoDisplay != null) {
                allSec = String(int(videoDisplay.duration % 60));
                allMin = String(int(videoDisplay.duration / 60));
            }
            if (allSec.length == 1) {
                allSec = "0" + allSec;
            }
            var allTime: String = allMin + ":" + allSec;

            if (!isCounted && commentTimerVpos > 10000) {
                //再生回数を加算
                var videoId: String = LibraryUtil.getVideoKey(this.videoPlayer.title);
                if (videoId != null) {
                    addVideoPlayCount(videoId, false);
                }
                isCounted = true;
            }

            //SWF再生時のタイムラインヘッダ移動・動画の終了判定
            if (isMovieClipPlaying && this.windowType == PlayerController.WINDOW_TYPE_SWF && this.mc != null) {

                videoPlayer.videoController_under.slider_timeline.enabled = true;
                videoPlayer.videoController_under.slider_timeline.minimum = 0;
                videoPlayer.videoController_under.slider_timeline.maximum = mc.totalFrames;

                videoPlayer.videoController.slider_timeline.enabled = true;
                videoPlayer.videoController.slider_timeline.minimum = 0;
                videoPlayer.videoController.slider_timeline.maximum = mc.totalFrames;

                if (!this.sliderChanging) {
                    videoPlayer.videoController_under.slider_timeline.value = mc.currentFrame;
                    videoPlayer.videoController.slider_timeline.value = mc.currentFrame;
                }

//				trace(nowMin + "/" + nowSec);

                videoPlayer.videoController_under.label_time.text = nowTime + "/" + allTime;
                videoPlayer.videoController.label_time.text = nowTime + "/" + allTime;

                if (mc.currentFrame >= mc.totalFrames - 1 || mc.currentFrame == this.lastFrame) {
                    this.lastFrame = mc.currentFrame;
                    //すでにmovieClipの終了呼び出しが行われているかどうか
                    if (!isMovieClipStopping) {
                        isMovieClipStopping = true;
                        movieClipCompleteHandler();
                    }
                    return;
                } else {
                    if (!isMovieClipStopping) {
                        this.lastFrame = mc.currentFrame;
                    }
                }
            }

            var tempTime: Number = (new Date).time;

            //SWF再生の時はここでコメントタイマーの時間を更新
            if (this.windowType == PlayerController.WINDOW_TYPE_SWF) {
                this.commentTimerVpos += (tempTime - this.time);
            }

            //コメントを更新
            var commentArray: Vector.<NNDDComment> = this.commentManager.setComment(
                commentTimerVpos,
                (tempTime - this.time) * 3,
                this.videoPlayer.isShowComment,
                this._isLengthwisePreferred
            );
            this.commentManager.moveComment(tempTime / 1000 - this.time / 1000, videoInfoView.showCommentSec);
            this.commentManager.removeComment(commentTimerVpos, videoInfoView.showCommentSec * 1000);
            this.time = tempTime;

            //コメントリストと同期させる場合の処理
            if (videoPlayer.videoInfoView.checkbox_SyncComment.selected && videoPlayer.videoInfoView.visible
//					&& (videoPlayer.stage.displayState != StageDisplayState.FULL_SCREEN_INTERACTIVE
//							&& videoInfoView.isActive)
            ) {

                var lastMin: String = commentManager.getComments().lastMin;

                var tempNowTime: String = nowTime;
                if (lastMin.length == 3) {
                    //最後の分が3桁（合計は:も含めて６桁）
                    if (tempNowTime.length == 4) {
                        //現在時刻が:を含めて4桁
                        tempNowTime = "00" + tempNowTime;
                    } else if (tempNowTime.length == 5) {
                        //現在時刻が:を含めて5桁
                        tempNowTime = "0" + tempNowTime;
                    }
                } else if (lastMin.length == 2) {
                    //最後の分が2桁（合計は:も含めて5桁）
                    if (tempNowTime.length == 4) {
                        //現在時刻が:を含めて4桁
                        tempNowTime = "0" + tempNowTime;
                    }

                } else if (lastMin.length == 1) {
                    //最後の分が1桁（合計は:も含めて4桁）

                }

                if (tempNowTime.length > lastMin.length + 3) {
                    tempNowTime = tempNowTime.substring(1);
                }


                var index: int = 0;
                if (commentArray.length > 0 && comments != null) {
                    var myComment: NNDDComment = commentArray[0];
                    for each(var comment: NNDDComment in commentArray) {
                        if (comment.vpos > myComment.vpos) {
                            myComment = comment;
                        }
                    }
                    index = comments.getCommentIndex(tempNowTime, myComment.text);

                    if (this.videoPlayer.videoInfoView.tabNavigator_comment.selectedIndex == 0) {

                        if (this.videoPlayer.videoInfoView.dataGrid_comment.verticalScrollPosition < index) {
                            index = index - (this.videoPlayer.videoInfoView.dataGrid_comment.rowCount) + 2;
                            if (index > 0) {
                                if (index < this.videoPlayer.videoInfoView.dataGrid_comment.maxVerticalScrollPosition) {
                                    this.videoPlayer.videoInfoView.dataGrid_comment.verticalScrollPosition = index;
                                } else {
                                    this.videoPlayer.videoInfoView.dataGrid_comment.verticalScrollPosition =
                                        this.videoPlayer.videoInfoView.dataGrid_comment.maxVerticalScrollPosition;
                                }
                            }
                        }

                    } else if (this.videoPlayer.videoInfoView.tabNavigator_comment.selectedIndex == 1) {

                        if (this.videoPlayer.videoInfoView.dataGrid_oldComment.verticalScrollPosition < index) {
                            index = index - (this.videoPlayer.videoInfoView.dataGrid_oldComment.rowCount) + 2;
                            if (index > 0) {
                                if (index <
                                    this.videoPlayer.videoInfoView.dataGrid_oldComment.maxVerticalScrollPosition) {
                                    this.videoPlayer.videoInfoView.dataGrid_oldComment.verticalScrollPosition = index;
                                } else {
                                    this.videoPlayer.videoInfoView.dataGrid_oldComment.verticalScrollPosition =
                                        this.videoPlayer.videoInfoView.dataGrid_oldComment.maxVerticalScrollPosition;
                                }
                            }
                        }

                    }

                }
            }


            //時報再生チェック
            var date: Date = new Date();
            var hh: String = new String(int(date.getHours()));
            var mm: String = new String(int(date.getMinutes()));
            if (hh.length == 1) {
                hh = "0" + hh;
            }
            if (mm.length == 1) {
                mm = "0" + mm;
            }
            var jihouResult: Array = commentManager.isJihouSettingTime(hh + mm);
            if (jihouResult != null && playingJihou == null) {
                //時報実行
                playingJihou = hh + mm;
                playNicowari(jihouResult[0], jihouResult[1]);
            }
            if (playingJihou != null && playingJihou != (hh + mm)) {
                playingJihou = null;
            }

            if (!this.videoPlayer.isShowComment) {
                this.commentManager.removeAll();
            }

        }

        /**
         * 引数で指定された実数をつかって音量を設定します。
         * @param volume 0から1までの間で指定できる音量です。
         * @return 対応する動画の音量です。
         *
         */
        public function setVolume(volume: Number): Number {
            if (this.windowReady) {
                if (this.windowType == PlayerController.WINDOW_TYPE_FLV) {
                    if (videoDisplay != null) {
                        videoDisplay.volume = volume;
                        this.videoPlayer.videoController.slider_volume.value = volume;
                        this.videoPlayer.videoController_under.slider_volume.value = volume;
                        return videoDisplay.volume;
                    }
                } else if (this.windowType == PlayerController.WINDOW_TYPE_SWF) {
                    if (mc != null) {
                        var transForm: SoundTransform = new SoundTransform(volume, 0);
                        mc.soundTransform = transForm;
                        this.videoPlayer.videoController.slider_volume.value = volume;
                        this.videoPlayer.videoController_under.slider_volume.value = volume;
                        return mc.soundTransform.volume;
                    }
                }
            }
            return 0;
        }

        /**
         * PlayerControllerが保持するCommentManagerを返します。
         * @return
         *
         */
        public function getCommentManager(): CommentManager {
            return commentManager;
        }

        /**
         * ウィンドウがリサイズされた際、コメントの表示位置をリセットします。
         * また、SWFを再生中は、ウィンドウサイズが変更された場合に、Loaderコンポーネントの大きさを変更します。
         */
        public function windowResized(isCommentRemove: Boolean): void {

            if (this.windowReady) {

                //SWFLoaderのコンポーネント大きさ調節
                if (swfLoader != null && this.windowType == PlayerController.WINDOW_TYPE_SWF) {
                    //スケール調節

                    (swfLoader.getChildAt(0) as Loader).x = 0;
                    (swfLoader.getChildAt(0) as Loader).y = 0;
                    var flashDistX: int = (swfLoader.getChildAt(0) as Loader).width - PlayerController.NICO_SWF_WIDTH;
                    var flashDistY: int = (swfLoader.getChildAt(0) as Loader).height - PlayerController.NICO_SWF_HEIGHT;
                    var scaleX: Number = swfLoader.width / ((swfLoader.getChildAt(0) as Loader).width - flashDistX);
                    var scaleY: Number = swfLoader.height / ((swfLoader.getChildAt(0) as Loader).height - flashDistY);
                    if (scaleX < scaleY) {
                        (swfLoader.getChildAt(0) as Loader).scaleX = scaleX;
                        (swfLoader.getChildAt(0) as Loader).scaleY = scaleX;
                        var centorY: int = swfLoader.height / 2;
                        var newY: int = centorY - (PlayerController.NICO_SWF_HEIGHT * scaleX) / 2;
//						trace("newY:"+newY);
                        if (newY > 0) {
                            (swfLoader.getChildAt(0) as Loader).y = newY;
                        }
                    } else {
                        (swfLoader.getChildAt(0) as Loader).scaleX = scaleY;
                        (swfLoader.getChildAt(0) as Loader).scaleY = scaleY;
                        var centorX: int = swfLoader.width / 2;
                        var newX: int = centorX - (PlayerController.NICO_SWF_WIDTH * scaleY) / 2;
//						trace("newX:"+newX);
                        if (newX > 0) {
                            (swfLoader.getChildAt(0) as Loader).x = newX;
                        }
                    }

                }

                //ニコ割SWFのコンポーネントの大きさ調節
                if (nicowariSwfLoader != null) {

                    (nicowariSwfLoader.getChildAt(0) as Loader).x = 0;
                    (nicowariSwfLoader.getChildAt(0) as Loader).y = 0;

                    var nicowariDistX: Number = (nicowariSwfLoader.getChildAt(0) as Loader).width -
                                                PlayerController.NICO_WARI_WIDTH;
                    var nicowariDistY: Number = (nicowariSwfLoader.getChildAt(0) as Loader).height -
                                                PlayerController.NICO_WARI_HEIGHT;

                    var nicowariScaleX: Number = nicowariSwfLoader.width /
                                                 ((nicowariSwfLoader.getChildAt(0) as Loader).width - nicowariDistX);
                    var nicowariScaleY: Number = nicowariSwfLoader.height /
                                                 ((nicowariSwfLoader.getChildAt(0) as Loader).height - nicowariDistY);
                    if (nicowariScaleX < nicowariScaleY) {
                        (nicowariSwfLoader.getChildAt(0) as Loader).scaleX = nicowariScaleX;
                        (nicowariSwfLoader.getChildAt(0) as Loader).scaleY = nicowariScaleX;
                        centorY = nicowariSwfLoader.height / 2;
                        newY = centorY - (PlayerController.NICO_WARI_HEIGHT * nicowariScaleX) / 2;
//						trace("newY:"+newY);
                        if (newY > 0) {
                            (nicowariSwfLoader.getChildAt(0) as Loader).y = newY;
                        }
                    } else {
                        (nicowariSwfLoader.getChildAt(0) as Loader).scaleX = nicowariScaleY;
                        (nicowariSwfLoader.getChildAt(0) as Loader).scaleY = nicowariScaleY;
                        centorX = nicowariSwfLoader.width / 2;
                        newX = centorX - (PlayerController.NICO_WARI_WIDTH * nicowariScaleY) / 2;
//						trace("newX:"+newX);
                        if (newX > 0) {
                            (nicowariSwfLoader.getChildAt(0) as Loader).x = newX;
                        }
                    }
                }

                if (isCommentRemove) {
                    // コメントを全て除去
                    commentManager.removeAll();
                } else {
                    // コメントの位置を再計算
                    commentManager.validateCommentPosition();
                }


            }
        }

        /**
         * 指定されたseekTimeまで動画のヘッドを移動させます。
         * @param seekTime タイムライン用のスライダが保持する値を設定します。単位はミリ秒です。
         *
         */
        public function seek(seekTime: Number): void {
            trace(seekTime);
            if (this.windowReady) {
                if ((new Date().time) - lastSeekTime > 1000) {
                    if ((videoDisplay != null && videoDisplay.initialized && videoDisplay.duration > 0) ||
                        (swfLoader != null && swfLoader.initialized)) {


                        trace("seekStart:" + seekTime);
                        this.commentTimer.stop();
                        this.commentTimer.reset();

                        //各コメントの表示可否フラグをリセット
                        commentManager.getComments().resetEnableShowFlag();

                        //コメントスクロール位置リセット
                        this.videoPlayer.videoInfoView.dataGrid_comment.verticalScrollPosition = 0;

                        if (this.windowType == PlayerController.WINDOW_TYPE_FLV) {
                            videoDisplay.seek(seekTime);
                            commentTimerVpos = seekTime * 1000;
                        } else if (this.windowType == PlayerController.WINDOW_TYPE_SWF) {
                            if (pausing) {
                                mc.gotoAndStop(int(seekTime));
                            } else {
                                mc.gotoAndPlay(int(seekTime));
                            }
                            commentTimerVpos = (seekTime / swfFrameRate) * 1000;
                        }

                        commentManager.removeAll();

                        if (!this.pausing) {
                            commentTimer.start();
                        }
                        lastSeekTime = new Date().time;


                    }
                }
            }
        }


        /**
         * 現在Playerが開いているかどうかを返します。
         * @return Playerが開いている場合はtrue、開いていない場合はfalse。
         *
         */
        public function isOpen(): Boolean {
            if (this.videoPlayer.nativeWindow != null) {
                return !this.videoPlayer.closed;
            }
            return false;
        }

        /**
         * PlayerウィンドウをOpenします。
         *
         */
        public function open(): Boolean {
            if (this.videoPlayer != null) {
                this.videoPlayer.open();
            } else {
                return false;
            }
            if (this.videoInfoView != null) {
                this.videoInfoView.open();
            } else {
                return false;
            }
            return true;
        }

        /**
         * 現在開いているPlayerの終了処理を行います
         *
         */
        public function playerExit(): void {

            this.stop();
            if (this.videoPlayer != null && this.videoPlayer.nativeWindow != null && !this.videoPlayer.closed) {
                this.videoPlayer.restore();
//				this.videoPlayer.saveStore();
                this.videoPlayer.close();
            }
            if (this.videoPlayer != null && this.videoInfoView.nativeWindow != null && !this.videoInfoView.closed) {
                this.saveNgList();
                this.videoInfoView.restore();
//				this.videoInfoView.saveStore();
                this.videoInfoView.close();
            }
        }

        /**
         * 指定された動画IDを動画を再生し直します。
         * このメソッドは、現在の再生状況(ストリーミング再生中か、ローカル再生中か)によって、
         * 再生するソースを切り替えます。
         *
         * @param videoId
         *
         */
        public function reload(videoId: String): void {

            stop();

            var nnddVideo: NNDDVideo = libraryManager.isExist(videoId);

            if (isStreamingPlay || nnddVideo == null) {
                playMovie("http://www.nicovideo.jp/watch/" + videoId);
            } else {
                playMovie(nnddVideo.getDecodeUrl());
            }

        }

        /**
         * 現状のNGリストを書き出します。
         *
         */
        public function saveNgList(): void {
            this.ngListManager.saveNgList(LibraryManagerBuilder.instance.libraryManager.systemFileDir);
        }

        public function getCommentListProvider(): ArrayCollection {
            return this.videoPlayer.getCommentListProvider();
        }

        public function getOwnerCommentListProvider(): ArrayCollection {
            return this.videoPlayer.videoInfoView.ownerCommentProvider;
        }


        /**
         * コメントを、NGリストを元にして最新に更新します。
         * @param date コメント読み込み開始日時
         */
        public function reloadLocalComment(date: Date = null): void {

            if (date != null) {
                trace(date.time);
            }

            if (this.videoInfoView.ngListProvider != null) {

                var videoMin: int = 1;
                if (this.windowType == PlayerController.WINDOW_TYPE_SWF && this.mc != null) {
                    videoMin = mc.totalFrames / swfFrameRate / 60;
                } else if (this.windowType == PlayerController.WINDOW_TYPE_FLV && this.videoDisplay != null) {
                    videoMin = videoDisplay.duration / 60;
                }
                ++videoMin;

                if (!this.isStreamingPlay && this.source != null && this.source != "") {
                    comments = new Comments(
                        PathMaker.createNomalCommentPathByVideoPath(source),
                        PathMaker.createOwnerCommentPathByVideoPath(source),
                        this.videoPlayer.getCommentListProvider(),
                        this.videoPlayer.videoInfoView.ownerCommentProvider,
                        this.ngListManager,
                        this.videoInfoView.isShowOnlyPermissionComment,
                        this.videoInfoView.isHideSekaShinComment,
                        this.videoInfoView.showCommentCountPerMin * videoMin,
                        this.videoInfoView.showOwnerCommentCountPerMin * videoMin,
                        this.videoInfoView.isNgUpEnable,
                        date
                    );
                } else if (this.isStreamingPlay) {
                    comments = new Comments(
                        PathMaker.createNomalCommentPathByVideoPath(
                            LibraryManagerBuilder.instance.libraryManager.tempDir.url + "/nndd.flv"
                        ),
                        PathMaker.createOwnerCommentPathByVideoPath(
                            LibraryManagerBuilder.instance.libraryManager.tempDir.url + "/nndd.flv"
                        ),
                        this.videoPlayer.getCommentListProvider(),
                        this.videoPlayer.videoInfoView.ownerCommentProvider,
                        this.ngListManager,
                        this.videoInfoView.isShowOnlyPermissionComment,
                        this.videoInfoView.isHideSekaShinComment,
                        this.videoInfoView.showCommentCountPerMin * videoMin,
                        this.videoInfoView.showOwnerCommentCountPerMin * videoMin,
                        this.videoInfoView.isNgUpEnable,
                        date
                        );
                }
                commentManager.setComments(comments);
            }

            this.windowResized(true);

        }

        /**
         * サムネイル情報及び市場情報をセットします。
         * @param videoPath
         *
         */
        private function setInfo(
            videoPath: String,
            thumbInfoPath: String,
            isStreaming: Boolean
        ): void {

            var videoID: String = PathMaker.getVideoID(videoPath);

            if (!isStreaming) { //ストリーミング再生では無い場合は、ローカル以外にもニコ動から取得したデータを設定する

                if (videoID != null) {

                    //初期化
                    videoPlayer.videoInfoView.owner_text_nico = "";

                } else {
                    var thumbInfoAnalyzer: ThumbInfoAnalyzer = null;

                    if (videoPath != null) {

                        var thumbInfoPath: String = PathMaker.createThmbInfoPathByVideoPath(videoPath);

                        var fileIO: FileIO = new FileIO(logManager);
                        var xml: XML = fileIO.loadXMLSync(thumbInfoPath, false);

                        if (xml != null) {
                            thumbInfoAnalyzer = new ThumbInfoAnalyzer(xml);
                        }
                    }

                    if (thumbInfoAnalyzer != null) {

                        var dateString: String = "(投稿日時の取得に失敗)";
                        var ownerText: String = "(投稿者説明文の取得に失敗)";
                        var htmlInfo: String = "";

                        if (thumbInfoAnalyzer != null) {
                            var dateFormatter: DateFormatter = new DateFormatter();
                            dateFormatter.formatString = "YYYY/MM/DD JJ:NN:SS";
                            var date: Date = thumbInfoAnalyzer.getDateByFirst_retrieve();
                            dateString = "投稿日:(削除されています)";
                            if (date != null) {
                                dateString = "投稿日:" + dateFormatter.format(date);
                            }

                            htmlInfo = thumbInfoAnalyzer.htmlTitle + "<br />" + dateString + "<br />" +
                                       thumbInfoAnalyzer.playCountAndCommentCountAndMyListCount;

                            ownerText = thumbInfoAnalyzer.thumbInfoHtml + "\n(ローカルのデータを使用)";
                        } else {

                            if (videoPlayer.videoInfoView.owner_text_local.length > 1) {
                                ownerText = videoPlayer.videoInfoView.owner_text_local + "\n(ローカルのデータを使用)";
                            }

                            htmlInfo = "(タイトルの取得に失敗)<br />" + dateString + "<br />(再生回数等の取得に失敗)";
                        }

                        videoPlayer.videoInfoView.text_info.htmlText = htmlInfo;

                        if (videoPlayer.videoInfoView.checkbox_showHtml.selected) {
                            videoPlayer.videoInfoView.owner_text_temp = videoPlayer.videoInfoView.owner_text_nico;
                            videoPlayer.videoInfoView.owner_text_nico = ownerText;
                        } else {
                            videoPlayer.videoInfoView.owner_text_temp = ownerText;
                        }

                        videoPlayer.videoInfoView.nicoTagProvider = thumbInfoAnalyzer.tagArray;
                        videoPlayer.videoInfoView.nicoTagProvider.push("(取得できなかったためローカルのデータを使用)");
                        videoPlayer.setTagArray(thumbInfoAnalyzer.tagStrings);

                    } else {

                        videoPlayer.videoInfoView.text_info.htmlText =
                            "(タイトルの取得に失敗)<br />(投稿日時の取得に失敗)<br />(再生回数等の取得に失敗)";
                        videoPlayer.videoInfoView.owner_text_nico = "(取得できませんでした)";

                        videoPlayer.videoInfoView.nicoTagProvider = videoPlayer.videoInfoView.localTagProvider;
                        videoPlayer.videoInfoView.nicoTagProvider.push("(取得できなかったためローカルのデータを使用)");

                        var tagStrings: Vector.<PlayerTagString> = new Vector.<PlayerTagString>();
                        for each(var string: String in videoPlayer.videoInfoView.nicoTagProvider) {
                            var tagString: PlayerTagString = new PlayerTagString(string);
                            tagStrings.push(tagString);
                        }
                        videoPlayer.setTagArray(tagStrings);

                    }
                }
            }

            if (videoID != null) {
                retryCount = 0;
                setNicoVideoPageInfo(PathMaker.getVideoID(videoID), 0, isStreaming);	//ストリーミングのとき説明文のみ取得
            }

            setNicoRelationInfo(videoID);	//関連情報はログイン無しに取得できるので常時取りに行く

            setLocalThumbInfo(videoID, thumbInfoPath, isStreaming);

        }


        //-------------------------------------------------------

        /**
         * 関連情報を再取得します。
         *
         */
        public function setNicoRelationInfoForRelationSortTypeChange(): void {
            var videoId: String = PathMaker.getVideoID(videoPlayer.title);
            if (videoId != null) {
                setNicoRelationInfo(videoId);
            }
        }

        /**
         * 指定された動画の関連情報を取得し、セットします。
         * @param videoID
         *
         */
        private function setNicoRelationInfo(videoID: String): void {

            (videoInfoView.relationDataProvider as ArrayCollection).removeAll();

            if (videoInfoView == null) {
                return;
            }

            if (nicoRelationInfoLoader != null) {
                try {
                    nicoRelationInfoLoader.close();
                } catch (error: Error) {
                }
            }

            videoInfoView.setRelationComboboxEnable(false);

            var sort: String = RelationTypeUtil.convertRelationSortType(videoInfoView.relationSortIndex);
            var order: String = RelationTypeUtil.convertRelationOrderType(videoInfoView.relationOrderIndex);

            logManager.addLog("オススメ動画情報を取得(videoId:" + videoID + ", sort:" + sort + ", order:" + order + ")");

            nicoRelationInfoLoader = new ApiGetRelation();
            nicoRelationInfoLoader.addEventListener(Event.COMPLETE, function (event: Event): void {
                (videoInfoView.relationDataProvider as ArrayCollection).removeAll();
                var analyzer: GetRelationResultAnalyzer = new GetRelationResultAnalyzer();
                analyzer.analyze(event.currentTarget.data);
                try {
                    event.currentTarget.close();
                } catch (error: Error) {
                }

                if ("ok" == analyzer.status) {
                    for each(var item: RelationResultItem in analyzer.videos) {
                        var pubDate: Date = new Date(item.time * 1000);
                        var info: String = HtmlUtil.convertSpecialCharacterNotIncludedString(item.title) + "\n" +
                                           "\t再生回数:" + NumberUtil.addComma(String(item.view)) + "\n" + "\tマイリスト:" +
                                           NumberUtil.addComma(String(item.mylist)) + ", コメント数:" +
                                           NumberUtil.addComma(String(item.comment)) + "\n" + "\t投稿日:" +
                                           DateUtil.getDateString(pubDate);
                        (videoInfoView.relationDataProvider as ArrayCollection).addItem({
                                                                                            col_image: item.thumbnail,
                                                                                            col_info: info,
                                                                                            col_link: item.url
                                                                                        });
                    }
                    if (videoInfoView.datagrid_relation != null) {
                        (videoInfoView.datagrid_relation as DataGrid).validateDisplayList();
                        (videoInfoView.datagrid_relation as DataGrid).validateNow();
                    }
                    logManager.addLog("オススメ動画の取得完了:" + event);
                    videoInfoView.setRelationComboboxEnable(true);

                } else {
                    logManager.addLog("オススメ動画の取得失敗:status=" + analyzer.status + "," + event);
                    (videoInfoView.relationDataProvider as ArrayCollection).addItem({
                                                                                        col_image: "",
                                                                                        col_info: "オススメ動画の取得に失敗(status=" +
                                                                                                  analyzer.status + ")",
                                                                                        col_link: null
                                                                                    });
                    if (videoInfoView.datagrid_relation != null) {
                        (videoInfoView.datagrid_relation as DataGrid).validateDisplayList();
                        (videoInfoView.datagrid_relation as DataGrid).validateNow();
                    }
                    videoInfoView.setRelationComboboxEnable(true);
                }

            });
            nicoRelationInfoLoader.addEventListener(
                HTTPStatusEvent.HTTP_RESPONSE_STATUS,
                function (event: HTTPStatusEvent): void {
                    logManager.addLog("\t" + event.toString());
                }
            );
            nicoRelationInfoLoader.addEventListener(IOErrorEvent.IO_ERROR, function (event: IOErrorEvent): void {
                (videoInfoView.relationDataProvider as ArrayCollection).removeAll();
                (videoInfoView.relationDataProvider as ArrayCollection).addItem({
                                                                                    col_image: "",
                                                                                    col_info: "オススメ動画の取得に失敗(通信エラー)",
                                                                                    col_link: null
                                                                                });
                logManager.addLog("オススメ動画の取得に失敗:" + event);
                try {
                    event.currentTarget.close();
                } catch (error: Error) {
                    trace(error.getStackTrace());
                }
                if (videoInfoView.datagrid_relation != null) {
                    (videoInfoView.datagrid_relation as DataGrid).validateDisplayList();
                    (videoInfoView.datagrid_relation as DataGrid).validateNow();
                }
                videoInfoView.setRelationComboboxEnable(true);
            });
            nicoRelationInfoLoader.getRelation(videoID, 1, sort, order);

            (videoInfoView.relationDataProvider as ArrayCollection).addItem({
                                                                                col_image: "",
                                                                                col_info: "オススメ動画を取得しています...",
                                                                                col_link: null
                                                                            });
            if (videoInfoView.datagrid_relation != null) {
                (videoInfoView.datagrid_relation as DataGrid).validateDisplayList();
                (videoInfoView.datagrid_relation as DataGrid).validateNow();
            }

        }

        /**
         * 投稿者説明文取得リトライ回数
         */
        private var retryCount: int = 0;

        /**
         * ニコニコ動画の動画ページに表示される最新の動画情報を取得・設定します。<br />
         * 動画情報とは、
         * ・タグ要素を含む投稿者説明文
         * ・サムネイル情報
         * ・市場情報
         * の３つです。
         *
         * @param videoId
         * @param delay
         *
         */
        private function setNicoVideoPageInfo(videoId: String, delay: int, onlyOwnerText: Boolean = false): void {

            if (retryCount > 3) {
                trace("setNicoVideoPageInfoのリトライオーバー");
                logManager.addLog("動画ページ詳細情報の取得に失敗(リトライオーバー):" + _videoID);
                return;
            } else {
                logManager.addLog("動画ページ詳細情報の取得開始(リトライ:" + retryCount + "):" + _videoID);
            }
            retryCount++;

            if (delay == 0) {
                getInfo(onlyOwnerText);
            } else {
                if (nicoVideoPageGetRetryTimer != null) {
                    nicoVideoPageGetRetryTimer.stop();
                    nicoVideoPageGetRetryTimer = null;
                }

                nicoVideoPageGetRetryTimer = new Timer(delay, 1);
                nicoVideoPageGetRetryTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function (event: Event): void {
                    trace("getInfo（遅延実行:" + retryCount + "）");
                    (event.currentTarget as Timer).stop();
                    getInfo(onlyOwnerText);
                });
                nicoVideoPageGetRetryTimer.start();
            }

            function getInfo(onlyOwnerText: Boolean): void {
                var watchVideoPage: NNDDVideoPageWatcher = new NNDDVideoPageWatcher();
                watchVideoPage.addEventListener(NNDDVideoPageWatcher.SUCCESS, function (event: Event): void {

                    try {
                        var fail: Boolean = false;

                        var description: String = watchVideoPage.watcher.getDescription();
                        if (description != null && description.length > 0) {

//							videoPlayer.videoInfoView.owner_text_nico = ThumbInfoUtil.encodeThumbInfo(description);

                            if (videoPlayer.videoInfoView.checkbox_showHtml.selected) {
                                videoPlayer.videoInfoView.owner_text_temp = videoPlayer.videoInfoView.owner_text_nico;
                                videoPlayer.videoInfoView.owner_text_nico = ThumbInfoUtil.encodeThumbInfo(description);
                            } else {
                                videoPlayer.videoInfoView.owner_text_temp = ThumbInfoUtil.encodeThumbInfo(description);
                            }

                        } else {
                            fail = true;
                        }

                        if (videoInfoView != null) {
                            if (watchVideoPage.watcher.getPubUserId() != null) {

                                trace(watchVideoPage.watcher.getPubUserName() + ", " +
                                      watchVideoPage.watcher.getPubUserId() + ", " +
                                      watchVideoPage.watcher.getPubUserIconUrl());

                                videoInfoView.pubUserId = "user/" + watchVideoPage.watcher.getPubUserId();
                                videoInfoView.pubUserLinkButtonText =
                                    "http://www.nicovideo.jp/" + videoInfoView.pubUserId;
                                videoInfoView.pubUserNameIconUrl = watchVideoPage.watcher.getPubUserIconUrl();
                                videoInfoView.pubUserName = watchVideoPage.watcher.getPubUserName();

                            } else {

                                trace(watchVideoPage.watcher.getChannelName() + ", " +
                                      watchVideoPage.watcher.getChannel() + ", " +
                                      watchVideoPage.watcher.getChannelIconUrl());

                                var id: String = watchVideoPage.watcher.getChannel();
                                if (id.match(/^[1-9][0-9]*$/)) {
                                    id = "ch" + id;
                                }
                                videoInfoView.pubUserId = "channel/" + id;
                                videoInfoView.pubUserLinkButtonText =
                                    "http://ch.nicovideo.jp/" + videoInfoView.pubUserId;
                                videoInfoView.pubUserNameIconUrl = watchVideoPage.watcher.getChannelIconUrl();
                                videoInfoView.pubUserName = watchVideoPage.watcher.getChannelName();

                            }


                            if (videoInfoView.pubUserLinkButton != null) {
                                videoInfoView.pubUserLinkButton.label = videoInfoView.pubUserLinkButtonText;
                                videoInfoView.image_pubUserIcon.source = videoInfoView.pubUserNameIconUrl;
                                videoInfoView.label_pubUserName.text = videoInfoView.pubUserName;
                            }
                        }

                        if (!watchVideoPage.onlyOwnerText) {
                            var thumbInfo: String = watchVideoPage.thumbInfoLoader.data;
                            if (thumbInfo != null) {
                                var analyzer: ThumbInfoAnalyzer = new ThumbInfoAnalyzer(new XML(thumbInfo));
                                var video: NNDDVideo = libraryManager.isExist(videoId);
                                if (analyzer.errorCode != null && analyzer.errorCode.length > 0 && !isStreamingPlay) {

                                    logManager.addLog("サムネイル情報取得時のエラーコード:" + analyzer.errorCode);

                                    // エラーコードが返ってきて、かつ、ストリーミングではないとき
                                    if (video != null) {

                                        logManager.addLog("ニコニコ動画からサムネイル情報が取得できなかったためローカルのデータを使用");

                                        if (analyzer.errorCode == ThumbInfoAnalyzer.ERROR_CODE_DELETED) {
                                            setVideoDeleted(true);
                                        } else {
                                            setVideoDeleted(false);
                                        }

                                        var thumbInfoPath: String = PathMaker.createThmbInfoPathByVideoPath(video.getDecodeUrl());
                                        var fileIO: FileIO = new FileIO();
                                        var xml: XML = fileIO.loadXMLSync(thumbInfoPath, false);
                                        analyzer = new ThumbInfoAnalyzer(xml);
                                    }

                                } else {
                                    if (video != null && video.pubDate == null) {
                                        video.pubDate = analyzer.getDateByFirst_retrieve();
                                        video.time = DateUtil.getTimeForThumbXML(analyzer.length);
                                        libraryManager.update(video, false);
                                    }
                                }
                                setNicoThumbInfo(analyzer);

                            } else {
                                fail = true;
                            }
                        }

                    } catch (error: Error) {
                        fail = true;
                        trace(error.getStackTrace());
                        logManager.addLog("エラー発生:" + error);
                    }

                    if (fail) {
                        setNicoVideoPageInfo(PathMaker.getVideoID(videoId), 1000 * retryCount);
                        logManager.addLog("動画ページ詳細情報の取得に失敗(リトライします)" + _videoID);
                    } else {
                        logManager.addLog("動画ページ詳細情報の取得に成功:" + _videoID);
                    }

                });
                watchVideoPage.addEventListener(NNDDVideoPageWatcher.FAIL, function (event: ErrorEvent): void {
                    logManager.addLog("動画ページ詳細情報の取得に失敗:" + _videoID + ":" + event.text);
                    trace("動画ページ詳細情報の取得に失敗:" + _videoID + ":" + event.text);
                });
                watchVideoPage.watch(
                    UserManager.instance.user,
                    UserManager.instance.password,
                    PathMaker.getVideoID(videoId),
                    onlyOwnerText
                );
            }
        }

        /**
         * サムネイル情報の解析結果を使ってPlayerのサムネイル情報を設定します。
         * @param analyzer
         *
         */
        private function setNicoThumbInfo(analyzer: ThumbInfoAnalyzer): void {

            videoPlayer.videoInfoView.nicoTagProvider = analyzer.tagArray;
            videoPlayer.setTagArray(analyzer.tagStrings);

            if (analyzer.tagArray.length == 0 && videoPlayer.videoInfoView.localTagProvider.length > 0) {
                videoPlayer.videoInfoView.nicoTagProvider = videoPlayer.videoInfoView.localTagProvider;
                videoPlayer.videoInfoView.nicoTagProvider.push("(取得できなかったためローカルのデータを使用)");

                var tagStrings: Vector.<PlayerTagString> = new Vector.<PlayerTagString>();
                for each(var string: String in videoPlayer.videoInfoView.nicoTagProvider) {
                    var tagString: PlayerTagString = new PlayerTagString(string);
                    tagStrings.push(tagString);
                }
                videoPlayer.setTagArray(tagStrings);
            }

            var dateString: String = "(投稿日時の取得に失敗)";
            var ownerText: String = "(投稿者説明文の取得に失敗)";
            var htmlInfo: String = "";

            var dateFormatter: DateFormatter = new DateFormatter();
            dateFormatter.formatString = "YYYY/MM/DD JJ:NN:SS";
            var date: Date = analyzer.getDateByFirst_retrieve();
            dateString = "投稿日:(削除されています)";
            if (date != null) {
                dateString = "投稿日:" + dateFormatter.format(date);
            }
            htmlInfo =
                analyzer.htmlTitle + "<br />" + dateString + "<br />" + analyzer.playCountAndCommentCountAndMyListCount;

            ownerText = analyzer.thumbInfoHtml;

            videoPlayer.videoInfoView.text_info.htmlText = htmlInfo;

            if (videoPlayer.videoInfoView.owner_text_nico.length == 0) {
                videoPlayer.videoInfoView.owner_text_nico = ownerText;
            }
        }

        public function setVideoDeleted(isDeleted: Boolean): void {
            if (isDeleted) {
                videoInfoView.label_deletedInfo.text = "【注意】この動画はニコニコ動画上では削除されています";
                videoInfoView.label_deletedInfo.toolTip = "ニコニコ動画上では削除されていますが、ダウンロード済みの動画/情報を使用して再生しています。";
                videoInfoView.label_deletedInfo.visible = true;
                videoInfoView.ownertext_comment_dividedbox.top = (videoInfoView.hgroup_thumbInfo.height + 24);
            } else {
                videoInfoView.label_deletedInfo.text = "";
                videoInfoView.label_deletedInfo.toolTip = null;
                videoInfoView.label_deletedInfo.visible = false;
                videoInfoView.ownertext_comment_dividedbox.top = (videoInfoView.hgroup_thumbInfo.height + 4);
            }
        }

        /**
         * サムネイル情報をセットします。
         *
         * @param thumbInfoPath
         * @param isStreaming trueの時は「ニコ動のデータ」として指定されたサムネイル情報を設定します。
         *
         */
        private function setLocalThumbInfo(videoId: String, thumbInfoPath: String, isStreaming: Boolean): void {

            var fileIO: FileIO = new FileIO(logManager);

            var fail: Boolean = false;
            try {
                var thumbInfoXML: XML = fileIO.loadComment(thumbInfoPath);

                if (thumbInfoXML == null) {
                    fail = true;
                } else {

                    var thumbInfoAnalyzer: ThumbInfoAnalyzer = new ThumbInfoAnalyzer(thumbInfoXML);

                    //ライブラリの情報をローカルのThumbInfo.xmlのタグ情報で更新
                    //ストリーミングの時はわたってくるvideoPathが純粋に動画の名前なのでスキップ
                    try {

                        //タグをライブラリに反映
                        var video: NNDDVideo = libraryManager.isExist(videoId);
                        if (video != null) {
                            var tagStrings: Vector.<String> = new Vector.<String>();
                            var tags: Array = thumbInfoAnalyzer.tagArray;
                            for (var i: int = 0; i < tags.length; i++) {
                                tagStrings.push(tags[i]);
                            }
                            video.tagStrings = tagStrings;
                            video.pubDate = thumbInfoAnalyzer.getDateByFirst_retrieve();
                            video.time = DateUtil.getTimeForThumbXML(thumbInfoAnalyzer.length);
                            //再生に時間がかかるのでライブラリの更新はしない
                            libraryManager.update(video, false);
                        }

                    } catch (error: ArgumentError) {
                        trace(error);
                    }

                    if (!isStreaming) {
                        videoPlayer.videoInfoView.localTagProvider = thumbInfoAnalyzer.tagArray;
                        videoPlayer.videoInfoView.owner_text_local = thumbInfoAnalyzer.thumbInfoHtml;
                        videoPlayer.videoInfoView.owner_text_nico = thumbInfoAnalyzer.thumbInfoHtml;
                    } else {
                        var dateFormatter: DateFormatter = new DateFormatter();
                        dateFormatter.formatString = "YYYY/MM/DD JJ:NN:SS";
                        var date: Date = thumbInfoAnalyzer.getDateByFirst_retrieve();
                        var dateString: String = "投稿日:(削除されています)";
                        if (date != null) {
                            dateString = "投稿日:" + dateFormatter.format(date);
                        }
                        videoPlayer.videoInfoView.nicoTagProvider = thumbInfoAnalyzer.tagArray;

                        if (videoPlayer.videoInfoView.checkbox_showHtml.selected) {
                            videoPlayer.videoInfoView.owner_text_temp = videoPlayer.videoInfoView.owner_text_nico;
                            videoPlayer.videoInfoView.owner_text_nico = thumbInfoAnalyzer.thumbInfoHtml;
                        } else {
                            videoPlayer.videoInfoView.owner_text_temp = thumbInfoAnalyzer.thumbInfoHtml;
                        }

                        videoPlayer.setTagArray(thumbInfoAnalyzer.tagStrings);
                        videoPlayer.videoInfoView.text_info.htmlText =
                            thumbInfoAnalyzer.htmlTitle + "<br />" + dateString + "<br />" +
                            thumbInfoAnalyzer.playCountAndCommentCountAndMyListCount;
                    }

                }

            } catch (error: Error) {
                fail = true;
                trace(error.getStackTrace());
            }

            if (fail) {
                if (isStreaming) {
                    videoPlayer.videoInfoView.text_info.htmlText =
                        videoPlayer.title + "<br />(投稿日の取得に失敗)<br />(再生回数等の取得に失敗)";
                    videoPlayer.videoInfoView.nicoTagProvider = new Array("タグ情報の取得に失敗");
                    videoPlayer.videoInfoView.owner_text_nico = "(投稿者説明文の取得に失敗)";

                    var temptags: Vector.<PlayerTagString> = new Vector.<PlayerTagString>();
                    var tagString: PlayerTagString = new PlayerTagString("(タグ情報の取得に失敗)");
                    temptags.push(tagString);
                    videoPlayer.setTagArray(temptags);
                } else {
                    var array: Array = new Array();
                    array.push("(ローカルにタグ情報無し)");
                    videoPlayer.videoInfoView.localTagProvider = array;
                    videoPlayer.videoInfoView.owner_text_local = "(ローカルに投稿者説明無し)";
                }
            }

        }


        /*--------------------------------------------------------------------*/

        /**
         * ユーザーニコ割の再生を行います。
         *
         * @param nivowariVideoID ユーザーニコ割動画ID
         * @param isStop ニコ割時に再生中の動画を停止するかどうか。
         *
         */
        public function playNicowari(nicowariVideoID: String, isStop: int = 1): void {

            // ニコ割の再生をしない設定ならスキップ
            if (videoInfoView.isNotPlayNicowari) {
                return;
            }

            //ニコ割領域を隠す設定になっていれば、再生前に表示。
            if (!videoInfoView.isShowAlwaysNicowariArea) {
                videoPlayer.showNicowariArea();
            }

            var mySource: String = this.source;
            if (isStreamingPlay) {
                mySource = libraryManager.tempDir.url + "/nndd.flv";
            }

            var nicoPath: String = PathMaker.createNicowariPathByVideoPathAndNicowariVideoID(mySource, nicowariVideoID);

            if (nicowariTimer != null) {
                pauseByNicowari(true);
                nicowariTimer.stop();
                nicowariTimer = null;
            }
            nicowariTimer = new Timer(100);

            var file: File = new File(nicoPath);
            if (!file.exists) {
                logManager.addLog("ユーザーニコ割がダウンロードされていない\nファイル:" + decodeURIComponent(file.url));
                videoPlayer.canvas_nicowari.removeAllChildren();
                videoPlayer.canvas_nicowari.setConstraintValue("backgroundColor", new int("0x969696"));
                var text: Text = new Text();
                text.text = "ユーザーニコ割がダウンロードされていません。(次のファイルを探しましたが発見できませんでした。)\n" +
                            decodeURIComponent(file.url).substring(decodeURIComponent(file.url).lastIndexOf("/") + 1);
                text.setConstraintValue("left", 10);
                text.setConstraintValue("top", 10);
                videoPlayer.canvas_nicowari.addChild(text);
                nicowariCloseTimer = new Timer(5000, 1);
                nicowariCloseTimer.addEventListener(TimerEvent.TIMER_COMPLETE, hideNicowari);
                nicowariCloseTimer.start();
                return;
            }

            var loader: Loader = new Loader();
            loader.contentLoaderInfo.addEventListener(Event.COMPLETE, function (event: Event): void {
                nicowariMC = loader.content as MovieClip;
                if (nicowariMC != null) {
                    var transForm: SoundTransform = new SoundTransform(
                        videoPlayer.videoController.slider_volume.value,
                        0
                    );
                    nicowariMC.soundTransform = transForm;
                    windowResized(false);
                    nicowariTimer.start();
                }
            });

            var fLoader: ForcibleLoader = new ForcibleLoader(loader);
            nicowariSwfLoader = new SWFLoader();
            nicowariSwfLoader.addChild(loader);
            nicowariSwfLoader.addEventListener(FlexEvent.UPDATE_COMPLETE, function (): void {
                windowResized(false);
            });
            this.videoPlayer.canvas_nicowari.setConstraintValue("backgroundColor", new int("0x000000"));
            this.videoPlayer.canvas_nicowari.removeAllChildren();
            this.videoPlayer.canvas_nicowari.addChild(nicowariSwfLoader);


            if (isStop == Command.NICOWARI_STOP) {
                pauseByNicowari();
            }

            nicowariSwfLoader.setConstraintValue("bottom", 0);
            nicowariSwfLoader.setConstraintValue("left", 0);
            nicowariSwfLoader.setConstraintValue("right", 0);
            nicowariSwfLoader.setConstraintValue("top", 0);

            fLoader.load(new URLRequest(nicoPath));

            nicowariTimer.addEventListener(TimerEvent.TIMER, function (): void {

                //ニコ割終了判定
                if (nicowariMC != null) {
                    var transForm: SoundTransform = new SoundTransform(
                        videoPlayer.videoController.slider_volume.value,
                        0
                    );
                    nicowariMC.soundTransform = transForm;
                    if (nicowariMC.currentFrame >= nicowariMC.totalFrames - 1 || nicowariMC.currentFrame ==
                        lastNicowariFrame) {
                        lastNicowariFrame = nicowariMC.currentFrame;
                        //ニコ割終了
                        pauseByNicowari(true);
                        nicowariTimer.stop();

                        //ニコ割領域を常時表示する設定か？
                        if (!videoInfoView.isShowAlwaysNicowariArea) {
                            //隠す設定なら5秒後にニコ割領域を隠す
                            videoPlayer.hideNicowariArea();
                        }
                    } else {
                        lastNicowariFrame = nicowariMC.currentFrame;
                    }
                }
            });

        }

        private function hideNicowari(event: TimerEvent): void {

            (event.currentTarget as Timer).removeEventListener(TimerEvent.TIMER_COMPLETE, hideNicowari);

            //ニコ割領域を常時表示する設定になっているか？
            if (!videoInfoView.isShowAlwaysNicowariArea) {
                //隠す設定なら5秒後にニコ割領域を隠す
                videoPlayer.hideNicowariArea();
            }

            nicowariCloseTimer = null;
        }


        /**
         * ニコ割による停止時に呼ばれます。
         * また、ニコ割による停止が解除された時にも呼ばれます。解除の際はisResetがtrueに設定されます。
         *
         * @param isReset
         *
         */
        private function pauseByNicowari(isReset: Boolean = false): void {
            if (!isReset) {
                if (!pausing) {
                    //一時停止していないので一時停止する
                    this.switchPlayer();
                }

                //再生ボタンを使えなくする
                this.videoPlayer.videoController.button_play.enabled = false;
                this.videoPlayer.videoController.button_stop.enabled = false;
                this.videoPlayer.videoController.slider_timeline.enabled = false;

                this.videoPlayer.videoController_under.button_play.enabled = false;
                this.videoPlayer.videoController_under.button_stop.enabled = false;
                this.videoPlayer.videoController_under.slider_timeline.enabled = false;

                trace("ニコ割再生");

            } else if (this.nicowariSwfLoader != null) {
                stopNicowari();
            }
        }

        /**
         * ニコ割を停止します
         * @return
         *
         */
        public function stopNicowari(): void {
            if (this.nicowariSwfLoader != null) {
                //ニコ割終了
                if (pausing) {
                    //一時停止していれば再生する
                    this.switchPlayer();
                }

                this.videoPlayer.canvas_nicowari.setConstraintValue("backgroundColor", new int("0x969696"));

                if (nicowariMC != null) {
                    nicowariMC.stop();
                }
                (this.nicowariSwfLoader.getChildAt(0) as Loader).unloadAndStop(true);
                this.nicowariSwfLoader = null;
                this.videoPlayer.canvas_nicowari.removeAllChildren();
                nicowariMC = null;

                //元に戻す
                this.videoPlayer.videoController.button_play.enabled = true;
                this.videoPlayer.videoController.button_stop.enabled = true;

                this.videoPlayer.videoController_under.button_play.enabled = true;
                this.videoPlayer.videoController_under.button_stop.enabled = true;

                trace("ニコ割停止");
            }
        }

        /**
         *
         * @param vpos
         *
         */
        public function seekOperation(vpos: Number): void {
            if (videoInfoView.isEnableJump) {
//				this.seek(vpos/1000);
                if (isPlayListPlaying && videoInfoView.isIgnoreJumpOnPlayList) {
                    logManager.addLog("プレイリスト再生中はジャンプ命令を無視(ジャンプ先:" + vpos + ")");
                } else {
                    this.seek(vpos);
                }
            } else {
                logManager.addLog("ジャンプ命令を無視(ジャンプ先:" + vpos + ")");
            }
        }


        /**
         * 指定されたvideoIDの動画に、メソッドが呼び出された3秒後にジャンプします。
         * messageが設定されている場合は、messageを画面に表示します。
         *
         * @param videoId
         * @param message
         * @return
         *
         */
        public function jump(videoId: String, message: String): void {

            //ジャンプ命令は有効か？
            if (videoInfoView.isEnableJump) {

                if (isPlayListPlaying && videoInfoView.isIgnoreJumpOnPlayList) {
                    logManager.addLog("プレイリスト再生中はジャンプ命令を無視(ジャンプ先:" + videoId + ")");
                } else {

                    //ジャンプ命令の際にユーザーに問い合わせる設定か？
                    if (videoInfoView.isAskToUserOnJump) {

                        if (!pausing) {
                            this.switchPlayer();
                        }
                        if (nicowariMC != null) {
                            this.pauseByNicowari(true);
                        }

                        videoPlayer.videoController.resetAlpha(true);

                        //問い合わせダイアログ表示
                        videoPlayer.showAskToUserOnJump(function (): void {
                            jumpStart(videoId, message);
                        }, function (): void {
                            switchPlayer();
                            logManager.addLog("ジャンプ命令をキャンセル(ジャンプ先:" + videoId + ")");
                        }, videoId);

                    } else {
                        jumpStart(videoId, message);
                    }
                }

            } else {
                logManager.addLog("ジャンプ命令を無視(ジャンプ先:" + videoId + ")");
            }


        }

        /**
         *
         * @param videoId
         * @param message
         *
         */
        private function jumpStart(videoId: String, message: String): void {

            this.stop();

            trace("@ジャンプ:videoId=" + videoId + ", message=" + message);

            if (message != null && message != "") {
                videoPlayer.label_downloadStatus.text = message + "(" + videoId + "にジャンプします...)";
            } else {
                videoPlayer.label_downloadStatus.text = videoId + "にジャンプします...";
            }
            logManager.addLog("ジャンプ命令:ジャンプ先=" + videoId + ", メッセージ=" + message);

            var timer: Timer = new Timer(3000, 1);
            timer.addEventListener(TimerEvent.TIMER_COMPLETE, function (event: TimerEvent): void {
                videoPlayer.label_downloadStatus.text = "";

                var url: String = "";
                var video: NNDDVideo = libraryManager.isExist(videoId);
                if (video == null) {
                    //無いときはニコ動にアクセス
                    url = "http://www.nicovideo.jp/watch/" + videoId;
                } else {
                    url = video.getDecodeUrl();
                }

                playMovie(url);
            });

            timer.start();
        }

        /**
         * PlayerとInfoViewのウィンドウの位置をリセットします。
         *
         */
        public function resetWindowPosition(): void {
            videoPlayer.resetWindowPosition();
            videoInfoView.resetWindowPosition();
        }

        /**
         * コメントのFPSを変更します。
         * @param fps
         *
         */
        public function changeFps(fps: Number): void {
            this.commentTimer.delay = 1000 / fps;
            this.videoPlayer.updateFrameRate();
        }

        /**
         * 渡されたURLで動画を再生します。
         *
         * @param url 再生したい動画のURL（ローカルの場合でもURL形式ならば有効）
         * @param playList プレイリストの場合はPlayListを指定
         * @param playListIndex プレイリスト内でどの項目を再生するか指定
         * @param videoTitle ストリーミング再生等で動画のタイトルを取得するのが難しい場合は動画のタイトルを指定します。
         * @param isEconomy エコノミーモードで再生するかどうかです。デフォルトではfalseで、エコノミーモードで再生しません。
         *
         */
        public function playMovie(
            url: String,
            playList: PlayList = null,
            playListIndex: int = -1,
            videoTitle: String = "",
            isEconomy: Boolean = false
        ): void {
            _playMovie(url, null, playList, playListIndex, videoTitle, isEconomy);
        }

        /**
         * 渡されたURLで動画を再生します。
         * 恐らく動画ソース変更時には必ず呼ばれる
         *
         * @param url 再生したい動画のURL（ローカルの場合でもURL形式ならば有効）
         * @param token Flash Media Serverの認証を行うためのトークン
         * @param playList プレイリストの場合はPlayListを指定
         * @param playListIndex プレイリスト内でどの項目を再生するか指定
         * @param videoTitle ストリーミング再生等で動画のタイトルを取得するのが難しい場合は動画のタイトルを指定します。
         * @param isEconomy エコノミーモードで再生するかどうかです。デフォルトではfalseで、エコノミーモードで再生しません。
         * @param isHLS HLSストリーミングかどうか
         * @param timer DMCサーバ使用時のハートビートタイマー
         */
        public function _playMovie(
            url: String,
            token: String = null,
            playList: PlayList = null,
            playListIndex: int = -1,
            videoTitle: String = "",
            isEconomy: Boolean = false,
            isHLS: Boolean = false,
            timer: Timer = null
        ): void {

            try {

                this._fmsToken = token;

                this.videoPlaying = true;

                if (videoInfoView != null) {
                    videoInfoView.videoServerUrl = "-";
                    videoInfoView.connectionType = "-";
                    videoInfoView.videoType = "-";
                    videoInfoView.messageServerUrl = "-";
                    videoInfoView.economyMode = "-";
                    videoInfoView.nickName = "-";
                    videoInfoView.isPremium = "-";
                    videoInfoView.format = "-";
                    videoInfoView.videoSize = "-";
                    videoInfoView.currentWindowSize = "-";

                    setVideoDeleted(false);
                }

                try {
                    if (nicoVideoPageGetRetryTimer !== null) {
                        nicoVideoPageGetRetryTimer.stop();
                        nicoVideoPageGetRetryTimer = null;
                    }
                    if (nicoVideoAccessRetryTimer !== null) {
                        nicoVideoAccessRetryTimer.stop();
                        nicoVideoAccessRetryTimer = null;
                    }
                    if (this._dmcHeartbeatTimer !== null) {
                        this._dmcHeartbeatTimer.stop();
                    }
                    stop();
                } catch (error: Error) {
                    trace(error.getStackTrace());
                }

                var urlArray: Array = null;
                var videoNameArray: Array = null;
                var playListName: String = null;

                if (playList != null) {
                    urlArray = new Array();
                    videoNameArray = new Array();

                    playListName = playList.name;
                    for each(var nnddVideo: NNDDVideo in playList.items) {
                        urlArray.push(nnddVideo.getDecodeUrl());
                        videoNameArray.push(nnddVideo.videoName);
                    }
                }

                this._isEconomyMode = isEconomy;
                this.isHLS = isHLS;
                this._dmcHeartbeatTimer = timer;

                url = decodeURIComponent(url);

                setPlayed(PathMaker.getVideoID(url));

                if (url.indexOf("http://") == -1 && url.indexOf("https://") == -1 && url.indexOf("rtmp") == -1) {
                    /* ---- ローカルの動画を再生 ---- */

                    videoPlayer.title = url;
                    videoPlayer.setControllerEnable(true);
                    logManager.addLog("***動画の再生(ローカル)***");

                    this.playerHistoryManager.addVideoUrl(url);

                    var file: File = new File(url);

                    var videoId: String = LibraryUtil.getVideoKey(decodeURIComponent(file.url));
                    var videoTitle: String = videoId;
                    var videoMin: int = 5;

                    if (videoId != null) {
                        var video: NNDDVideo = null;

                        video = libraryManager.isExist(videoId);
                        if (video != null) {
                            videoTitle = video.getVideoNameWithVideoID();
                            if (file.exists) {
                                //ファイルが存在して、動画も存在するなら動画のURLを更新しておく
                                video.uri = file.url;
                                video.thumbUrl = PathMaker.createThumbImgFilePath(file.url, false);

                                //動画の時間が0ならサムネイル情報を見に行って更新する
                                if (video.time == 0) {
                                    var tempVideo: NNDDVideo = new LocalVideoInfoLoader().loadInfo(decodeURIComponent(
                                        file.url));
                                    if (tempVideo != null) {
                                        video.time = tempVideo.time;
                                    }
                                }
                                videoMin = video.time / 60;
                                ++videoMin;

                                libraryManager.update(video, false);
                            }
                            url = video.getDecodeUrl();
                            file = new File(video.getDecodeUrl());

                            this._isEconomyMode = video.isEconomy;

                        } else {
                            if (file.exists) {
                                //ファイルが存在して、動画が存在しないなら新しく登録
                                video = new LocalVideoInfoLoader().loadInfo(decodeURIComponent(file.url));
                                if (video == null) {
                                    video = new NNDDVideo(file.url, file.name);
                                }

                                videoMin = video.time / 60;
                                ++videoMin;

                                libraryManager.add(video, false);
                                logManager.addLog("動画を管理対象に追加:" + file.nativePath);
                            }
                        }
                    }

                    if (!file.exists) {
                        Alert.show(
                            Message.M_FILE_NOT_FOUND_REFRESH + "\n" + file.nativePath,
                            Message.M_ERROR,
                            4,
                            this.videoPlayer
                        );
                        logManager.addLog(Message.M_FILE_NOT_FOUND_REFRESH + "\n" + file.nativePath);
                        return;
                    }

                    var commentPath: String = PathMaker.createNomalCommentPathByVideoPath(url);
                    var ownerCommentPath: String = PathMaker.createOwnerCommentPathByVideoPath(url);
                    var comments: Comments = new Comments(
                        commentPath,
                        ownerCommentPath,
                        this.getCommentListProvider(),
                        this.getOwnerCommentListProvider(),
                        this.ngListManager,
                        this.videoInfoView.isShowOnlyPermissionComment,
                        this.videoInfoView.isHideSekaShinComment,
                        this.videoInfoView.showCommentCountPerMin * videoMin,
                        this.videoInfoView.showOwnerCommentCountPerMin * videoMin,
                        this.videoInfoView.isNgUpEnable
                    );

                    if (url.indexOf(".swf") != -1 || url.indexOf(".SWF") != -1) {
                        if (playList != null && playListIndex != -1) {
                            this.initWithPlayList(
                                url,
                                PlayerController.WINDOW_TYPE_SWF,
                                comments,
                                urlArray,
                                videoNameArray,
                                playListName,
                                playListIndex,
                                true,
                                false,
                                null,
                                videoTitle
                            );
                        } else {
                            this.isPlayListingPlay = false;
                            this.init(
                                url,
                                PlayerController.WINDOW_TYPE_SWF,
                                comments,
                                PathMaker.createThmbInfoPathByVideoPath(url, false),
                                true,
                                false,
                                null,
                                false,
                                videoTitle
                            );
                        }
                    } else if (url.indexOf(".mp4") != -1 || url.indexOf(".MP4") != -1 || url.indexOf(".flv") != -1 ||
                               url.indexOf(".FLV") != -1) {
                        if (playList != null && playListIndex != -1) {
                            this.initWithPlayList(
                                url,
                                PlayerController.WINDOW_TYPE_FLV,
                                comments,
                                urlArray,
                                videoNameArray,
                                playListName,
                                playListIndex,
                                true,
                                false,
                                null,
                                videoTitle
                            );
                        } else {
                            this.isPlayListingPlay = false;
                            this.init(
                                url,
                                PlayerController.WINDOW_TYPE_FLV,
                                comments,
                                PathMaker.createThmbInfoPathByVideoPath(url, false),
                                true,
                                false,
                                null,
                                false,
                                videoTitle
                            );
                        }
                    }
                } else if (
                    (url.match(new RegExp("https?://smile.*")) != null) ||
                    (url.match(new RegExp("http://[^/]+/NNDDServer/.*")) != null) ||
                    (url.match(new RegExp("rtmp[^:]*://smile.*")) != null) ||
                    (url.match(new RegExp("https?://[a-z0-9]+\.dmc\.nico")) != null)
                ) {

                    /* ストリーミング再生(接続先動画サーバがわかっている時) */

                    logManager.addLog("***動画の再生(ストリーミング)***");

                    if (url.indexOf("rtmp") == 0) {
                        Alert.show(
                            videoPlayer.title + " を再生できませんでした。\n\nこの動画はrtmp形式で配信されていますが、NNDDはrtmp形式の動画の再生に対応していません。",
                            "エラー",
                            4,
                            this.videoPlayer
                        );
                        logManager.addLog("rtmp形式の動画の再生には非対応:" + url);

                        return;
                    }

                    var commentPath: String = libraryManager.tempDir.url + "/nndd.xml";
                    var ownerCommentPath: String = libraryManager.tempDir.url + "/nndd[Owner].xml";

                    var loader: LocalVideoInfoLoader = new LocalVideoInfoLoader();
                    var video: NNDDVideo = loader.loadInfo(libraryManager.tempDir.resolvePath("nndd.flv").nativePath);
                    videoMin = 5;
                    if (video != null) {
                        videoMin = video.time / 60;
                        ++videoMin;
                    }

                    var comments: Comments = new Comments(
                        commentPath,
                        ownerCommentPath,
                        this.getCommentListProvider(),
                        this.getOwnerCommentListProvider(),
                        this.ngListManager,
                        this.videoInfoView.isShowOnlyPermissionComment,
                        this.videoInfoView.isHideSekaShinComment,
                        this.videoInfoView.showCommentCountPerMin * videoMin,
                        this.videoInfoView.showOwnerCommentCountPerMin * videoMin,
                        this.videoInfoView.isNgUpEnable
                    );

                    videoPlayer.label_downloadStatus.text = "";

                    //ストリーミング再生のときはthis.vieoURL（videoIDが含まれる方）を使う。
                    if (videoTitle.indexOf(".swf") != -1 || videoTitle.indexOf(".SWF") != -1) {

                        if (playList != null && playListIndex != -1) {
                            this.initWithPlayList(
                                url,
                                PlayerController.WINDOW_TYPE_SWF,
                                comments,
                                urlArray,
                                videoNameArray,
                                playListName,
                                playListIndex,
                                true,
                                true,
                                libraryManager.tempDir.url + "/nndd.flv",
                                videoTitle
                            );
                        } else {
                            this.isPlayListingPlay = false;
                            this.init(
                                url,
                                WINDOW_TYPE_SWF,
                                comments,
                                libraryManager.tempDir.url + "/nndd[ThumbInfo].xml",
                                true,
                                true,
                                videoTitle,
                                false,
                                videoTitle
                            );
                        }
                    } else if (
                        videoTitle.indexOf(".mp4") != -1 ||
                        videoTitle.indexOf(".MP4") != -1 ||
                        videoTitle.indexOf(".flv") != -1 ||
                        videoTitle.indexOf(".FLV") != -1
                    ) {
                        if (playList != null && playListIndex != -1) {
                            this.initWithPlayList(
                                url,
                                PlayerController.WINDOW_TYPE_FLV,
                                comments,
                                urlArray,
                                videoNameArray,
                                playListName,
                                playListIndex,
                                true,
                                true,
                                libraryManager.tempDir.url + "/nndd.flv",
                                videoTitle
                            );
                        } else {
                            this.isPlayListingPlay = false;
                            this.init(
                                url,
                                WINDOW_TYPE_FLV,
                                comments,
                                libraryManager.tempDir.url + "/nndd[ThumbInfo].xml",
                                true,
                                true,
                                videoTitle,
                                false,
                                videoTitle
                            );
                        }
                    }
                } else if (url.match(/https?:\/\/www\.nicovideo\.jp\/watch\//)) {

                    /* ストリーミング再生(接続先動画サーバがまだわかっていない時) */

                    logManager.addLog("***ストリーミング再生の準備***");

                    this.playerHistoryManager.addVideoUrl(url);

                    videoPlayer.title = url;
                    videoPlayer.setControllerEnable(false);

                    try {

                        destructor();
                        videoPlayer.label_downloadStatus.text = "ニコニコ動画にアクセスしています...";

                        var tempDir: File = new File(libraryManager.libraryDir.url + "/temp/");
                        if (tempDir.exists) {
                            tempDir.moveToTrash();
                        }

                        tempDir = new File(libraryManager.tempDir.url);
                        if (tempDir.exists) {
                            var itemList: Array = tempDir.getDirectoryListing();
                            for each(var tempFile: File in itemList) {
                                if (!tempFile.isDirectory) {
                                    try {
                                        tempFile.deleteFile();
                                    } catch (error: Error) {
                                        trace(error.getStackTrace());
                                    }
                                }
                            }
                        }


                        if (nnddDownloaderForStreaming != null) {
                            nnddDownloaderForStreaming.close(true, false);
                            nnddDownloaderForStreaming = null;
                        }

                        nnddDownloaderForStreaming = new NNDDDownloader();
                        nnddDownloaderForStreaming._isEnableGetVideoFromOtherNNDDServer = searchNNDDServerVideo;
                        nnddDownloaderForStreaming._otherNNDDServerAddress = nnddServerAddress;
                        nnddDownloaderForStreaming._otherNNDDServerPort = nnddServerPortNum;
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.DOWNLOAD_PROCESS_COMPLETE,
                            function (event: Event): void {
                                _playMovie(
                                    (event.target as NNDDDownloader).streamingUrl,
                                    (event.target as NNDDDownloader).fmsToken,
                                    playList,
                                    playListIndex,
                                    FileIO.getSafeFileName((event.target as NNDDDownloader).nicoVideoName),
                                    nnddDownloaderForStreaming.isEconomyMode,
                                    nnddDownloaderForStreaming.isHLS,
                                    nnddDownloaderForStreaming.createDmcBeatingTimer()
                                );

                                removeStreamingPlayHandler(event);
                                nnddDownloaderForStreaming = null;

                                var downloader: NNDDDownloader = (event.currentTarget as NNDDDownloader);
                                if (downloader != null && videoInfoView != null) {
                                    if (downloader.messageServerURL != null) {
                                        videoInfoView.messageServerUrl = downloader.messageServerURL;
                                    }

                                    if (downloader.getFlvResultAnalyzer != null) {
                                        videoInfoView.economyMode = String(downloader.getFlvResultAnalyzer.economyMode);
                                        videoInfoView.nickName = downloader.getFlvResultAnalyzer.nickName;
                                        videoInfoView.isPremium = String(downloader.getFlvResultAnalyzer.isPremium);
                                    }
                                }

                            }
                        );

                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.COMMENT_GET_START,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.GETFLV_API_ACCESS_START,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.LOGIN_START,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.NICOWARI_GET_START,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.OWNER_COMMENT_GET_START,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.THUMB_IMG_GET_START,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.THUMB_INFO_GET_START,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.VIDEO_GET_START,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.WATCH_START,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.CREATE_DMC_SESSION_START,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.REMOTE_NNDD_SERVER_ACCESS_SUCCESS,
                            getProgressListener
                        );

                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.COMMENT_GET_SUCCESS,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.GETFLV_API_ACCESS_SUCCESS,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.LOGIN_SUCCESS,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.LOGIN_SKIP,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.NICOWARI_GET_SUCCESS,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.OWNER_COMMENT_GET_SUCCESS,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.THUMB_IMG_GET_SUCCESS,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.THUMB_INFO_GET_SUCCESS,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.VIDEO_GET_SUCCESS,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.WATCH_SUCCESS,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.CREATE_DMC_SESSION_SUCCESS,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.DOWNLOAD_PROCESS_COMPLETE,
                            getProgressListener
                        );

                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.COMMENT_GET_FAIL,
                            getFailListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.GETFLV_API_ACCESS_FAIL,
                            getFailListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.LOGIN_FAIL,
                            getFailListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.NICOWARI_GET_FAIL,
                            getFailListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.OWNER_COMMENT_GET_FAIL,
                            getFailListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.THUMB_IMG_GET_FAIL,
                            getFailListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.THUMB_INFO_GET_FAIL,
                            getFailListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.VIDEO_GET_FAIL,
                            getFailListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.WATCH_FAIL,
                            getFailListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.CREATE_DMC_SESSION_FAIL,
                            getProgressListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.DOWNLOAD_PROCESS_ERROR,
                            streamingPlayFailListener
                        );
                        nnddDownloaderForStreaming.addEventListener(
                            NNDDDownloader.DOWNLOAD_PROCESS_CANCELD,
                            streamingPlayFailListener
                        );
                        nnddDownloaderForStreaming.requestDownloadForStreaming(
                            UserManager.instance.user,
                            UserManager.instance.password,
                            PathMaker.getVideoID(url),
                            tempDir,
                            videoInfoView.isAlwaysEconomyForStreaming,
                            FlexGlobals.topLevelApplication.getUseOldTypeCommentGet()
                        );

                    } catch (e: Error) {
                        videoPlayer.label_downloadStatus.text = "";
                        videoPlayer.setControllerEnable(true);

                        Alert.show("ストリーミング再生中に予期せぬ例外が発生しました。\nError:" + e, Message.M_ERROR, 4, this.videoPlayer);
                        logManager.addLog("ストリーミング再生中に予期せぬ例外が発生しました。\nError:" + e + ":" + e.getStackTrace());
                        nnddDownloaderForStreaming.close(true, true);
                        nnddDownloaderForStreaming = null;
                    }
                }

                logManager.addLog(Message.PLAY_VIDEO + ":" + decodeURIComponent(url));

            } catch (error: Error) {
                trace(error.getStackTrace());
                videoPlayer.setControllerEnable(true);
                Alert.show(url + "を再生できませんでした。\n" + error, Message.M_ERROR, 4, this.videoPlayer);
                logManager.addLog("再生できませんでした:url=[" + url + "]\n" + error.getStackTrace());
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
            } else if (event.type == NNDDDownloader.CREATE_DMC_SESSION_FAIL) {
                status = "DMCサーバ接続失敗";
            } else if (event.type == NNDDDownloader.VIDEO_GET_FAIL) {
                status = "動画取得失敗";
            }

            logManager.addLog("\t" + status + ":" + event.type + ":" + event.text);
            videoPlayer.label_downloadStatus.text = videoPlayer.label_downloadStatus.text + "\n\t" + status;
        }

        /**
         *
         * @param event
         *
         */
        public function getProgressListener(event: Event): void {
            var status: String = null;
            if (event.type == NNDDDownloader.LOGIN_SUCCESS) {
                status = "成功";
            } else if (event.type == NNDDDownloader.LOGIN_SKIP) {
                status = "スキップ";
            } else if (event.type == NNDDDownloader.WATCH_SUCCESS) {
                status = "成功";
            } else if (event.type == NNDDDownloader.GETFLV_API_ACCESS_SUCCESS) {
                status = "成功";
            } else if (event.type == NNDDDownloader.COMMENT_GET_SUCCESS) {
                status = "成功";
            } else if (event.type == NNDDDownloader.OWNER_COMMENT_GET_SUCCESS) {
                status = "成功";
            } else if (event.type == NNDDDownloader.NICOWARI_GET_SUCCESS) {
                status = "成功";
            } else if (event.type == NNDDDownloader.THUMB_INFO_GET_SUCCESS) {
                status = "成功";
            } else if (event.type == NNDDDownloader.THUMB_IMG_GET_SUCCESS) {
                status = "成功";
            } else if (event.type == NNDDDownloader.CREATE_DMC_SESSION_SUCCESS) {
                status = "成功";
            } else if (event.type == NNDDDownloader.VIDEO_GET_SUCCESS) {
                status = "成功";
            }

            if (event.type == NNDDDownloader.LOGIN_START) {
                status = "ログインしています...";
            } else if (event.type == NNDDDownloader.WATCH_START) {
                status = "動画ページにアクセスしています...";
            } else if (event.type == NNDDDownloader.GETFLV_API_ACCESS_START) {
                status = "動画取得APIにアクセスしています...";
            } else if (event.type == NNDDDownloader.COMMENT_GET_START) {
                status = "コメントを取得しています...";
            } else if (event.type == NNDDDownloader.OWNER_COMMENT_GET_START) {
                status = "投稿者コメントを取得しています...";
            } else if (event.type == NNDDDownloader.NICOWARI_GET_START) {
                status = "ニコ割を取得しています...";
            } else if (event.type == NNDDDownloader.THUMB_INFO_GET_START) {
                status = "サムネイル情報を取得しています...";
            } else if (event.type == NNDDDownloader.THUMB_IMG_GET_START) {
                status = "サムネイル画像を取得しています...";
            } else if (event.type == NNDDDownloader.CREATE_DMC_SESSION_START) {
                status = "DMCサーバに接続しています...";
            } else if (event.type == NNDDDownloader.VIDEO_GET_START) {
                status = "動画を取得しています...";
            }

            if (event.type == NNDDDownloader.REMOTE_NNDD_SERVER_ACCESS_SUCCESS) {
                status = "代替URLを使用(" + (event.currentTarget as NNDDDownloader).nnddServerVideoUrl + ")";
            }

            trace(status);
            if ("成功" == status) {
                videoPlayer.label_downloadStatus.text = videoPlayer.label_downloadStatus.text + " " + status;
            } else {
                videoPlayer.label_downloadStatus.text = videoPlayer.label_downloadStatus.text + "\n\t" + status;
            }
        }

        /**
         *
         * @param event
         *
         */
        public function streamingPlayFailListener(event: Event): void {
            var tempStr: String = videoPlayer.label_downloadStatus.text;
            if (event.type == NNDDDownloader.DOWNLOAD_PROCESS_CANCELD) {
                stop();
                videoPlayer.label_downloadStatus.text = tempStr + "\n\nアクセスをキャンセルしました。";
                logManager.addLog("***ストリーミング再生をキャンセル***");
            } else if (event.type == NNDDDownloader.DOWNLOAD_PROCESS_ERROR) {
                stop();
                videoPlayer.label_downloadStatus.text =
                    tempStr + "\n\n動画を取得できませんでした。\n" + (event as IOErrorEvent).text + "\n" + event;
                logManager.addLog(NNDDDownloader.DOWNLOAD_PROCESS_ERROR + ":" + event + ":" +
                                  (event as IOErrorEvent).text);
                logManager.addLog("***ストリーミング再生に失敗***");
            }

            var downloader: NNDDDownloader = (event.currentTarget as NNDDDownloader);
            if (downloader != null && videoInfoView != null) {
                if (downloader.messageServerURL != null) {
                    videoInfoView.messageServerUrl = downloader.messageServerURL;
                }

                if (downloader.getFlvResultAnalyzer != null) {
                    var url: String = downloader.getFlvResultAnalyzer.url;
                    if (url != null) {
                        var index: int = url.indexOf("?");
                        if (index != -1) {
                            url = url.substring(0, index);
                        }
                    }
                    videoInfoView.videoServerUrl = url;
                    videoInfoView.economyMode = String(downloader.getFlvResultAnalyzer.economyMode);
                    videoInfoView.nickName = downloader.getFlvResultAnalyzer.nickName;
                    videoInfoView.isPremium = String(downloader.getFlvResultAnalyzer.isPremium);

                }
            }

            removeStreamingPlayHandler(event);
            this.nnddDownloaderForStreaming = null;
        }

        /**
         * ストリーミング再生のURL取得に使うNNDDDownloaderからリスナを除去します。
         * @param event
         *
         */
        public function removeStreamingPlayHandler(event: Event): void {
//			(event.target as NNDDDownloader).removeEventListener(NNDDDownloader.DOWNLOAD_PROCESS_COMPLETE, stremaingPlayStartSuccess);
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.DOWNLOAD_PROCESS_CANCELD,
                streamingPlayFailListener
            );
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.DOWNLOAD_PROCESS_ERROR,
                streamingPlayFailListener
            );
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.COMMENT_GET_FAIL, getFailListener);
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.GETFLV_API_ACCESS_FAIL,
                getFailListener
            );
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.LOGIN_FAIL, getFailListener);
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.NICOWARI_GET_FAIL, getFailListener);
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.OWNER_COMMENT_GET_FAIL,
                getFailListener
            );
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.THUMB_IMG_GET_FAIL, getFailListener);
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.THUMB_INFO_GET_FAIL, getFailListener);
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.VIDEO_GET_FAIL, getFailListener);
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.CREATE_DMC_SESSION_FAIL,
                getFailListener
            );
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.WATCH_FAIL, getFailListener);

            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.COMMENT_GET_SUCCESS,
                getProgressListener
            );
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.GETFLV_API_ACCESS_SUCCESS,
                getProgressListener
            );
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.LOGIN_SUCCESS, getProgressListener);
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.LOGIN_SKIP, getProgressListener);
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.NICOWARI_GET_SUCCESS,
                getProgressListener
            );
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.OWNER_COMMENT_GET_SUCCESS,
                getProgressListener
            );
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.THUMB_IMG_GET_SUCCESS,
                getProgressListener
            );
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.THUMB_INFO_GET_SUCCESS,
                getProgressListener
            );
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.VIDEO_GET_SUCCESS, getProgressListener);
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.CREATE_DMC_SESSION_SUCCESS,
                getFailListener
            );
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.WATCH_SUCCESS, getProgressListener);
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.DOWNLOAD_PROCESS_COMPLETE,
                getProgressListener
            );

            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.COMMENT_GET_START, getProgressListener);
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.GETFLV_API_ACCESS_START,
                getProgressListener
            );
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.LOGIN_START, getProgressListener);
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.NICOWARI_GET_START,
                getProgressListener
            );
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.OWNER_COMMENT_GET_START,
                getProgressListener
            );
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.THUMB_IMG_GET_START,
                getProgressListener
            );
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.THUMB_INFO_GET_START,
                getProgressListener
            );
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.VIDEO_GET_START, getProgressListener);
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.CREATE_DMC_SESSION_START,
                getFailListener
            );
            (event.target as NNDDDownloader).removeEventListener(NNDDDownloader.WATCH_START, getProgressListener);
            (event.target as NNDDDownloader).removeEventListener(
                NNDDDownloader.REMOTE_NNDD_SERVER_ACCESS_SUCCESS,
                getProgressListener
            );
        }

        /**
         * プレイリスト一覧をロードし直します。
         */
        public function loadPlayListSummry(): void {
//			playListManager.readPlayListSummary(libraryManager.playListDir);
            (FlexGlobals.topLevelApplication as NNDD).updatePlayListSummery();
        }

        /**
         * 指定されたインデックスのプレイリストを再度読み込みます
         * @param index
         *
         */
        public function loadPlayList(index: int = -1): void {
//			playListManager.getPlay(index);
            (FlexGlobals.topLevelApplication as NNDD).updatePlayList(index);
        }

        /**
         * 指定された名前のプレイリストのインデックスを返します。
         * @param title
         * @return
         *
         */
        public function getPlayListIndexByName(title: String): int {
            return playListManager.getPlayListIndexByName(title);
        }

        /**
         * プレイリストを新規作成します。
         * @param name
         *
         */
        public function addNewPlayList(urlArray: Array, videoNameArray: Array): String {
            //プレイリスト新規作成
            var title: String = playListManager.addPlayList(null);
            var index: int = playListManager.getPlayListIndexByName(title);

            var videoArray: Array = new Array();
            for (var i: int = 0; i < urlArray.length; i++) {
                var nnddVideo: NNDDVideo = new NNDDVideo(urlArray[i], videoNameArray[i]);
                videoArray.push(nnddVideo);
            }

            playListManager.addNNDDVideos(index, videoArray, 0);

            (FlexGlobals.topLevelApplication as NNDD).updatePlayList(index);
            (FlexGlobals.topLevelApplication as NNDD).updatePlayListSummery();

            return title;
        }

        /**
         * 指定されたタイトルのプレイリストを上書きします。プレイリストが存在しない場合は新規作成します。
         * @param title
         * @param urlArray
         * @param videoNameArray
         *
         */
        public function updatePlayList(title: String, urlArray: Array, videoNameArray: Array): void {
            var index: int = playListManager.getPlayListIndexByName(title);
            if (index == -1) {
                addNewPlayList(urlArray, videoNameArray);
            } else {

                var vector: Vector.<NNDDVideo> = new Vector.<NNDDVideo>();
                for (var i: int = 0; i < urlArray.length; i++) {
                    vector.push(new NNDDVideo(urlArray[i], videoNameArray[i]));
                }

                playListManager.updatePlayList(title, vector);

                (FlexGlobals.topLevelApplication as NNDD).updatePlayListSummery();
                (FlexGlobals.topLevelApplication as NNDD).updatePlayList(index);

            }
        }

        /**
         *
         *
         */
        public function watchOnWeb(): void {
            var videoId: String = PathMaker.getVideoID(this.videoPlayer.title);
            if (videoId != null) {
                WebServiceAccessUtil.openNiconicoDougaForVideo(videoId);
            } else {
                Alert.show("動画IDが見つからないため、URLを特定できませんでした。", Message.M_ERROR, 4, this.videoPlayer);
                logManager.addLog("ニコ動での閲覧に失敗:動画IDが見つからないため、URLを特定できませんでした。");
            }
        }

        /**
         * 再生中の項目をTwitterでつぶやきます
         *
         */
        public function tweet(): void {

            var title: String = this.videoPlayer.title;
            if (title != null && title.length > 0) {

                var videoId: String = PathMaker.getVideoID(title);
                WebServiceAccessUtil.tweet(videoId, title);
            }
        }

        /**
         * 再生中の項目をはてなブックマークに追加します。
         *
         */
        public function addHatenaBookmark(): void {

            var title: String = this.videoPlayer.title;

            if (title.length > 0) {

                var videoId: String = PathMaker.getVideoID(title);
                WebServiceAccessUtil.addHatenaBookmark(videoId, title);
            }
        }

        /**
         * 再生中の項目をNicoSoundで開きます
         *
         */
        public function openNicoSound(): void {

            var title: String = this.videoPlayer.title;

            if (title.length > 0) {
                var videoId: String = PathMaker.getVideoID(title);
                WebServiceAccessUtil.openNicoSound(videoId);
            }


        }


        /**
         *
         *
         */
        public function addDlList(): void {
            var videoId: String = PathMaker.getVideoID(this.videoPlayer.title);
            var thumbUrl: String = (videoInfoView.image_thumbImg.source as String);

            if (videoId != null) {
                var video: NNDDVideo = new NNDDVideo(
                    WatchVideoPage.WATCH_VIDEO_PAGE_URL + videoId,
                    this.videoPlayer.title
                );
                if (thumbUrl != null) {
                    video.thumbUrl = thumbUrl;
                }
                (FlexGlobals.topLevelApplication as NNDD).addDownloadListForInfoView(video);
                logManager.addLog("InfoViewからDLリストへ追加:" + video.getDecodeUrl());
            } else {
                Alert.show("動画IDが見つからないため、DLリストに追加できませんでした。", Message.M_ERROR, 4, this.videoPlayer);
                logManager.addLog("DLリストへの追加失敗:動画IDが見つからないため、DLリストに動画を追加できませんでした。");
            }
        }


        /**
         * 表示するコメントの太字を切り替えます。
         * @param isFontBold
         *
         */
        public function setCommentFontBold(isFontBold: Boolean): void {
            commentManager.setCommentBold(isFontBold);
        }

        /**
         *
         * @param myListId
         *
         */
        public function addMyList(myListId: String): void {
            var videoTitle: String = videoPlayer.title;
            var videoId: String = PathMaker.getVideoID(videoTitle);

            if (!PlayerMylistAddr.instance.isAdding) {
                PlayerMylistAddr.instance.addMyList(
                    UserManager.instance.user,
                    UserManager.instance.password,
                    myListId,
                    videoId,
                    videoTitle
                );
            } else {
                PlayerMylistAddr.instance.close();
            }

        }

        /**
         *
         * @param isVisible
         *
         */
        public function setCommentVisible(isVisible: Boolean): void {
            if (this.commentManager != null) {
                this.commentManager.setCommentVisible(isVisible);
            }
        }


        /**
         *
         * @param font
         *
         */
        public function setFont(fontName: String): void {
            if (fontName != null) {
                if (this.videoInfoView != null) {
                    this.videoInfoView.setStyle("fontFamily", fontName);
                }
                if (this.videoPlayer != null) {
                    this.videoPlayer.setStyle("fontFamily", fontName);
                }
            }
        }

        /**
         *
         * @param size
         *
         */
        public function setFontSize(size: int): void {
            if (this.videoInfoView != null) {
                this.videoInfoView.setChangeFontSize(size);
                this.videoInfoView.setStyle("fontSize", size);
            }
            if (this.videoPlayer != null) {
                this.videoPlayer.setStyle("fontSize", size);
            }
        }

        /**
         * 一つ前の動画に戻ります。
         *
         */
        public function back(): void {
            var nnddVideo: NNDDVideo = playerHistoryManager.back();
            if (nnddVideo != null) {
                this.stop();
                if (!isPlayListingPlay) {
                    // 通常再生中
                    playMovie(nnddVideo.getDecodeUrl());
                } else if (this.videoInfoView.getPlayList().length > 0) {
                    // プレイリスト再生中
                    if (playingIndex >= this.videoInfoView.getPlayList().length - 1) {
                        playingIndex = this.videoInfoView.getPlayList().length - 1;
                        if (this.videoPlayer.videoInfoView.isRepeatAll()) {
                            playMovie(this.videoInfoView.getPlayListUrl(playingIndex),
                                      this.videoInfoView.playList,
                                      playingIndex,
                                      PathMaker.getVideoName(this.videoInfoView.getPlayListUrl(playingIndex))
                            );
                        }
                    } else {
                        playingIndex--;
                        playMovie(this.videoInfoView.getPlayListUrl(playingIndex),
                                  this.videoInfoView.playList,
                                  playingIndex,
                                  PathMaker.getVideoName(this.videoInfoView.getPlayListUrl(playingIndex))
                        );
                    }
                } else {
                    isPlayListingPlay = false;
                }
            }
        }

        /**
         * 次の動画に進みます。これはプレイリストを再生している場合にのみ有効です。
         *
         */
        public function next(): void {
            if (isPlayListingPlay && this.videoInfoView.getPlayList().length > 0) {
                // プレイリスト再生中
                if (playingIndex >= this.videoInfoView.getPlayList().length - 1) {
                    playingIndex = 0;
                    if (this.videoPlayer.videoInfoView.isRepeatAll()) {
                        playMovie(this.videoInfoView.getPlayListUrl(playingIndex),
                                  this.videoInfoView.playList,
                                  playingIndex,
                                  PathMaker.getVideoName(this.videoInfoView.getPlayListUrl(playingIndex))
                        );
                    }
                } else {
                    playingIndex++;
                    playMovie(this.videoInfoView.getPlayListUrl(playingIndex),
                              this.videoInfoView.playList,
                              playingIndex,
                              PathMaker.getVideoName(this.videoInfoView.getPlayListUrl(playingIndex))
                    );
                }
            } else {
                isPlayListingPlay = false;
            }
        }

        /**
         * 現在プレイリストを再生中かどうかを返す
         * @reutrn
         */
        public function get isPlayListPlaying(): Boolean {
            return this.isPlayListingPlay;
        }

        /**
         * プレイリストにおける、現在再生中の動画のインデックスを返す
         * @return
         *
         */
        public function get playingIndexOnPlaylist(): int {
            return this.playingIndex;
        }

        public function set isLengthwisePreferred(value: Boolean): void {
            this._isLengthwisePreferred = value;
        }

        /**
         * 指定された動画がローカルのマイリストに存在する場合、マイリストの動画を既読に設定します。
         * @param videoId
         *
         */
        public function setPlayed(videoId: String): void {
            // マイリストの既読設定
            if (videoId == null) {
                return;
            }

            var myListIds: Vector.<String> = MyListManager.instance.searchMyListIdWithPrefix(videoId);
            if (myListIds != null && myListIds.length > 0) {
                for each(var myListId: String in myListIds) {
                    var videoIds: Vector.<String> = new Vector.<String>();
                    videoIds.push(videoId);

                    var type: RssType = MyListManager.checkType(myListId);
                    myListId = myListId.substring(myListId.indexOf("/"));
                    MyListManager.instance.updatePlayedAndSave(myListId, type, videoIds, true);
                }
            }
        }

    }

}