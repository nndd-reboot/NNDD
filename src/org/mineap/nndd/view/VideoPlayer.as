/**
 * VideoPlayer.as
 *
 * @author shiraminekeisuke(MineAP)
 *
 */

import flash.data.EncryptedLocalStore;
import flash.desktop.Clipboard;
import flash.desktop.ClipboardFormats;
import flash.desktop.NativeDragActions;
import flash.desktop.NativeDragManager;
import flash.display.NativeMenu;
import flash.display.NativeWindowDisplayState;
import flash.display.NativeWindowType;
import flash.display.StageDisplayState;
import flash.events.ContextMenuEvent;
import flash.events.Event;
import flash.events.FullScreenEvent;
import flash.events.IOErrorEvent;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.events.NativeDragEvent;
import flash.events.NativeWindowBoundsEvent;
import flash.events.TextEvent;
import flash.events.TimerEvent;
import flash.filesystem.File;
import flash.filters.DropShadowFilter;
import flash.geom.Rectangle;
import flash.system.Capabilities;
import flash.text.TextField;
import flash.ui.ContextMenuItem;
import flash.ui.Keyboard;
import flash.ui.Mouse;
import flash.utils.Timer;

import mx.collections.ArrayCollection;
import mx.containers.Canvas;
import mx.controls.Alert;
import mx.controls.Button;
import mx.controls.HSlider;
import mx.controls.Text;
import mx.controls.TextArea;
import mx.core.Application;
import mx.core.FlexGlobals;
import mx.core.UITextField;
import mx.core.Window;
import mx.events.AIREvent;
import mx.events.FlexEvent;
import mx.events.ListEvent;
import mx.events.ResizeEvent;
import mx.managers.PopUpManager;

import org.mineap.nndd.LogManager;
import org.mineap.nndd.Message;
import org.mineap.nndd.model.NNDDSearchType;
import org.mineap.nndd.model.NNDDVideo;
import org.mineap.nndd.model.SearchItem;
import org.mineap.nndd.model.SearchSortString;
import org.mineap.nndd.playList.PlayListManager;
import org.mineap.nndd.player.PlayerController;
import org.mineap.nndd.player.model.PlayerTagString;
import org.mineap.nndd.util.PathMaker;
import org.mineap.nndd.util.ShortUrlChecker;
import org.mineap.util.config.ConfUtil;
import org.mineap.util.config.ConfigManager;

public var isShowComment: Boolean = true;

public var isRepeat: Boolean = false;

public var isAlwaysFront: Boolean = false;

public var isNicowariShow: Boolean = true;

public var nowRatio: Number = 1.0;

private var playerController: PlayerController;
public var videoInfoView: VideoInfoView;
private var storeWidth: Number = 40;

public var isResize: Boolean = false;

public var lastRect: Rectangle = new Rectangle();

private var logManager: LogManager;

private var videoPlayer: VideoPlayer;

private var text_key_info: Text;

private var isUnderControllerHideComplete: Boolean = true;

private var seekTimer: Timer;
private var seekValue: Number = 0;

private var _copyVideoInfoView: VideoInfoView = null;

private var _jumpDialog: JumpDialog = null;

private var isMouseHideEnable: Boolean = false;

public var isMouseHide: Boolean = false;

private var videoSourceSelectWindow: VideoSourceSelectWindow = null;

private var windowPosition_x: Number;
private var windowPosition_y: Number;

private var isWindowPositionSetupCompleted: Boolean = false;

[Bindable]
public var textAreaTagProvider: String = "";

public function init(playerController: PlayerController, videoInfoView: VideoInfoView, logManager: LogManager): void {
    this.videoPlayer = this;
    this.videoInfoView = videoInfoView;
    this.logManager = logManager;
    this.playerController = playerController;

    this.addEventListener(FlexEvent.CREATION_COMPLETE, function (event: FlexEvent): void {
        videoController.init(playerController, videoPlayer, logManager);
        videoController.width = int(canvas_videoPlayer.width - canvas_videoPlayer.width / 4);
        videoController_under.init(playerController, videoPlayer, logManager, false);
        stage.addEventListener(KeyboardEvent.KEY_DOWN, keyListener);
        stage.addEventListener(KeyboardEvent.KEY_UP, keyUpListener);
        stage.addEventListener(MouseEvent.MOUSE_OVER, mouseOverEventHandler);
        stage.addEventListener(MouseEvent.MOUSE_OUT, mouseOutEventHandler);
        stage.addEventListener(FullScreenEvent.FULL_SCREEN, fullScreen);
        playerController.resizePlayerJustVideoSize();
        videoController.resetAlpha(true);

        updateFrameRate();

    });

    readStore();

}

protected function windowComplete(event: AIREvent): void {
    this.setStyle("fontFamily", ConfigManager.getInstance().getItem("fontFamily"));
    this.setStyle("fontSize", Number(ConfigManager.getInstance().getItem("fontSize")));
}

public function resetInfo(): void {
    this.textAreaTagProvider = "";
    this.title = "Player - NNDD";
}

/**
 *
 * @param tags
 *
 */
public function setTagArray(tags: Vector.<PlayerTagString>): void {
    var text: String = "";

    // すべてのタグを見せるかどうか
    var showAll: Boolean = false;
    var showAllStr: String = ConfigManager.getInstance().getItem("showAllTag");
    if (showAllStr != null) {
        showAll = ConfUtil.parseBoolean(showAllStr);
        if (showAll) {
            logManager.addLog("Playerですべてのタグを表示");
        }
    } else {
        ConfigManager.getInstance().setItem("showAllTag", "false");
        ConfigManager.getInstance().save();
    }

    // 見せるロケール
    var showLoc: String = "jp";
    if (showAll == false) {
        var loc: String = ConfigManager.getInstance().getItem("showTagLoc");
        if (loc == null) {
            ConfigManager.getInstance().setItem("showTagLoc", "jp");
            ConfigManager.getInstance().save();
        } else {
            // e.g. "jp","tw","es","de"
            showLoc = loc;
        }
        logManager.addLog("表示するタグのロケール:" + showLoc);
    }

    for each(var tagStr: PlayerTagString in tags) {
        var tag: String = tagStr.tag;

        if (showAll == false && tagStr.loc != showLoc) {
            // このロケールは見せない
            continue;
        }

        if (tag != null && tag.indexOf("(取得できなかった") == -1 && tag.indexOf("(タグ情報の取得に失敗)") == -1) {
            var lockStr: String = "";
            if (tagStr.lock) {
                lockStr = "<font color=\"#ff0000\" size=\"8\">[LOCK]</font> ";
            }

            // 実体参照に置き換え
            // "&amp;" represents the & sign.
            // "&lt;" represents the < sign.
            // "&gt;" represents the > sign.
            // "&quot;" represents the " mark.

            var myPattern: RegExp = new RegExp("&", "g");
            var replacedTagStr: String = tag.replace(myPattern, "&amp;");

            myPattern = new RegExp("<", "g");
            replacedTagStr = replacedTagStr.replace(myPattern, "&lt;");
            myPattern = new RegExp(">", "g");
            replacedTagStr = replacedTagStr.replace(myPattern, "&gt;");
            myPattern = new RegExp("\"", "g");
            replacedTagStr = replacedTagStr.replace(myPattern, "&quot;");

            text += "<a href=\"event:" + replacedTagStr + "\"><u><font color=\"#0000ff\">" + replacedTagStr +
                    "</font></u></a>" + "<a href=\"http://dic.nicovideo.jp/a/" + encodeURIComponent(tag) +
                    "\"><font color=\"#0000ff\">【<u>百</u>】</font></a>" + lockStr + "  ";
        } else {
            text += tag + "  ";
        }
    }

    if (showAll == false && text.length == 0) {
        text = "この言語で表示できるタグはありません(ロケール:" + showLoc + ")";
    }

    this.textAreaTagProvider = text;
}

protected function changeShowVideoInfoView(event: Event): void {
    if (videoInfoView != null) {
        if ((videoInfoView as Window).visible) {
            hideVideoInfoView();
        } else {
            videoInfoView.visible = true;
            showVideoPlayerAndVideoInfoView();
        }
    }
}

private var inhibitActivate: Boolean = false;

public function showVideoPlayerAndVideoInfoView(forcePlayerFront: Boolean = false): void {
    if (videoInfoView != null) {

//		trace("ShowVideoInfoView");

        if (this.nativeWindow != null && !this.closed && videoInfoView.nativeWindow != null && videoInfoView.visible ==
            true) {
            videoInfoView.visible = true;
            videoInfoView.nativeWindow.orderToFront();

            if (videoInfoView.isPlayerFollow) {
                followInfoView(lastRect);
            }
            if (videoInfoView.isFollowInfoViewHeight) {
                resizeInfoView();
            }

        }

    }

    if (this.nativeWindow != null && !this.closed) {
        if (forcePlayerFront) {
            this.nativeWindow.activate();
        } else {
            this.nativeWindow.orderToFront();
        }
    }
}

public function hideVideoInfoView(): void {
    if (videoInfoView != null) {
        (videoInfoView as Window).visible = false;
    }
}

/**
 *
 * @param event
 *
 */
public function tagListDoubleClickEventHandler(event: ListEvent): void {
    if (event.itemRenderer.data != null) {
        if (event.itemRenderer.data is String) {
            var word: String = String(event.itemRenderer.data);
            FlexGlobals.topLevelApplication.search(new SearchItem(word,
                                                                  SearchSortString.convertSortTypeFromIndex(4),
                                                                  NNDDSearchType.TAG,
                                                                  word
            ));
        }
    }
}

private function mouseMove(event: MouseEvent): void {
    this.videoController.resetAlpha(false);
}

private function windowResized(event: NativeWindowBoundsEvent): void {

    lastRect = event.afterBounds;

    if (this.nativeWindow.x == windowPosition_x && this.nativeWindow.y == windowPosition_y) {
        isWindowPositionSetupCompleted = true;
    }

    followInfoView(lastRect);
    resizeInfoView();

    if (playerController != null) {
        (playerController as PlayerController).setVideoSmoothing(videoInfoView.isSmoothing);
    }
}

/**
 * ウィンドウの移動の際に呼ばれるイベントハンドラ。
 * @param event
 *
 */
private function windowMove(event: NativeWindowBoundsEvent): void {
    lastRect = event.afterBounds;

    if (Capabilities.os.toLowerCase().indexOf("linux") > -1) {
        var timer: Timer = new Timer(100, 1);
        timer.addEventListener(TimerEvent.TIMER_COMPLETE, function (event: TimerEvent): void {
            var rect: Rectangle = new Rectangle(this.nativeWindow.x,
                                                this.nativeWindow.y,
                                                this.nativeWindow.width,
                                                this.nativeWindow.height
            );
            lastRect = rect;
            followInfoView(lastRect);
            resizeInfoView();
        }, false, 0, true);
    } else {
        followInfoView(lastRect);
        resizeInfoView();
    }
}

public function resizeInfoView(): void {
    if (isWindowPositionSetupCompleted && this.videoInfoView != null && this.nativeWindow != null &&
        this.videoInfoView.nativeWindow != null && this.videoInfoView.visible &&
        this.videoInfoView.nativeWindow.displayState != NativeWindowDisplayState.MINIMIZED // infoViewが最小化されていない
        && this.nativeWindow.displayState != NativeWindowDisplayState.MINIMIZED 	// videoPlayerが最小化されていない
        && this.videoInfoView.isFollowInfoViewHeight 										// 追従が有効になっている
        && this.stage.displayState != StageDisplayState.FULL_SCREEN_INTERACTIVE) {	// videoPlayerがフルスクリーンではない

        this.videoInfoView.nativeWindow.height = this.nativeWindow.height;
        this.videoInfoView.validateNow();

    }

}

public function followInfoView(lastRect: Rectangle): void {
    if (isWindowPositionSetupCompleted && lastRect != null && this.videoInfoView != null && this.nativeWindow != null &&
        !this.closed	// playerが閉じられたあとではない
        && this.visible && this.videoInfoView.nativeWindow != null && !this.videoInfoView.closed	// infoviewが閉じられたあとではない
        && this.videoInfoView.visible && this.videoInfoView.nativeWindow.displayState !=
        NativeWindowDisplayState.MINIMIZED // infoViewが最小化されていない
        && this.nativeWindow.displayState != NativeWindowDisplayState.MINIMIZED 	// videoPlayerが最小化されていない
        && this.videoInfoView.isPlayerFollow 										// 追従が有効になっている
        && this.stage.displayState != StageDisplayState.FULL_SCREEN_INTERACTIVE) {	// videoPlayerがフルスクリーンではない
        this.videoInfoView.nativeWindow.x = lastRect.x + lastRect.width;
        this.videoInfoView.nativeWindow.y = lastRect.y;
    }
}

/**
 *
 * @param event
 *
 */
private function playListContextMenuItemDisplayingEventHandler(event: Event): void {
    var item: ContextMenuItem = (event.currentTarget as ContextMenuItem);

    if (item != null) {

        item.submenu = new NativeMenu();

        var nameArray: Array = PlayListManager.instance.getPlayListNames();
        for each(var name: String in nameArray) {
            var menuItem: ContextMenuItem = new ContextMenuItem(name);
            menuItem.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, addPlayListContextMenuItemClicked);
            item.submenu.addItem(menuItem);
        }

    }
}

/**
 *
 * @param event
 *
 */
private function addPlayListContextMenuItemClicked(event: ContextMenuEvent): void {
    var contextMenuItem: ContextMenuItem = (event.target as ContextMenuItem);
    var name: String = contextMenuItem.label;
    var pIndex: int = PlayListManager.instance.getPlayListIndexByName(name);

    var videoId: String = PathMaker.getVideoID(this.title);

    if (videoId == null) {
        return;
    }
    var videos: Array = new Array();
    videos.push(new NNDDVideo("http://www.nicovideo.jp/watch/" + videoId, this.title));

    PlayListManager.instance.addNNDDVideos(pIndex, videos);

}

/**
 *
 * @param ratio
 *
 */
private function changeWindowSizeRatio(ratio: Number, force: Boolean): void {
    if (this.nativeWindow != null) {

        this.resetFull();

        (this.canvas_video_back as Canvas).setFocus();

        if (nowRatio != ratio || force) {

            this.nowRatio = ratio;

            playerController.resizePlayerJustVideoSize(this.nowRatio);

        }

    }
}

private function windowClosing(event: Event): void {

    this.playerController.isPlayerClosing = true;

//	if(this.stage.displayState == StageDisplayState.FULL_SCREEN_INTERACTIVE){
//		this.videoInfoView.changeFull();
//	}

    (this as Window).restore();

    saveStore();

    if (canvas_video != null) {
        canvas_video.removeAllChildren();
    }

    if (videoSourceSelectWindow != null) {
        videoSourceSelectWindow.close();
    }

    this.playerController.saveNgList();

    this.playerController.stop();

    this.playerController.destructor();

}

private function windowClosed(): void {

    if (videoInfoView != null) {
        ConfigManager.getInstance().removeItem("videoInfoViewVisible");
        ConfigManager.getInstance().setItem("videoInfoViewVisible", this.videoInfoView.visible);
    }

    this.videoInfoView.saveStore();

    if (this.videoInfoView != null && !this.videoInfoView.closed) {
        hideVideoInfoView();
    }

    this.playerController.destructor();
}

public function getCommentListProvider(): ArrayCollection {
    return this.videoInfoView.commentListProvider;
}

public function label_playSourceStatusInit(event: Event): void {

    label_playSourceStatus.setStyle("color", new int("0xFFFFFF"));
    label_playSourceStatus.setStyle("fontAntiAliasType", AntiAliasType.ADVANCED);
    var filterArray: Array = new Array();
    filterArray.push(new DropShadowFilter(1));
    label_playSourceStatus.filters = filterArray;
}

public function label_economyStatusInit(event: Event): void {
    label_economyStatus.setStyle("color", new int("0xFFFFFF"));
    label_economyStatus.setStyle("fontAntiAliasType", AntiAliasType.ADVANCED);
    var filterArray: Array = new Array();
    filterArray.push(new DropShadowFilter(1));
    label_economyStatus.filters = filterArray;

}

public function hbox_displayLabelsInit(event: Event): void {

    var filterArray: Array = new Array();
    filterArray.push(new DropShadowFilter(1));

    button_x1.filters = filterArray;
    button_x1_5.filters = filterArray;
    button_x2.filters = filterArray;
    button_ChangeFullScreen.filters = filterArray;
    button_ChangeShowInfoView.filters = filterArray;
    button_ChangeRepeat.filters = filterArray;
    button_ChangeShowComment.filters = filterArray;

}

public function setIsShowComment(isShowComment: Boolean): void {
    if (!isShowComment) {
        button_ChangeShowComment.setStyle("color", new int("0x646464"));
    } else {
        button_ChangeShowComment.setStyle("color", new int("0xffffff"));
    }
    playerController.setCommentVisible(isShowComment);
}

public function setIsRepeat(isRepeat: Boolean): void {
    if (!isRepeat) {
        button_ChangeRepeat.setStyle("color", new int("0x646464"));
    } else {
        button_ChangeRepeat.setStyle("color", new int("0xffffff"));
    }
}

public function changeIsShowComment(): void {
    isShowComment = !isShowComment;
    setIsShowComment(isShowComment);
}

public function changeIsRepeat(): void {
    isRepeat = !isRepeat;
    setIsRepeat(isRepeat);
}

public function changeRepateButtonClicked(event: Event): void {
    changeIsRepeat();
}

public function changeShowCommentButtonClicked(event: Event): void {
    changeIsShowComment();
}

public function changeRepeatCreationComplete(event: Event): void {
    setIsRepeat(isRepeat);
}

public function changeShowCommentCreationComplete(event: Event): void {
    setIsShowComment(this.isShowComment);
    playerController.setCommentVisible(this.isShowComment);
}

private function fullScreen(event: FullScreenEvent): void {

    if (event.fullScreen) {
        this.videoPlayer.button_ChangeFullScreen.label = Message.L_NORMAL;
        showUnderController(false, false);
        showTagArea(false, false);

        vbox_videoPlayer.setConstraintValue("bottom", 0);
        vbox_videoPlayer.setConstraintValue("left", 0);
        vbox_videoPlayer.setConstraintValue("right", 0);
        vbox_videoPlayer.setConstraintValue("top", 0);
        vbox_videoPlayer.setConstraintValue("backgroundColor", new int("0x000000"));
        this.showStatusBar = false;

    } else {
        //このイベントはキャッチされない？
        trace("ESC_fullScreen");
        vbox_videoPlayer.setConstraintValue("bottom", 5);
        vbox_videoPlayer.setConstraintValue("left", 5);
        vbox_videoPlayer.setConstraintValue("right", 5);
        vbox_videoPlayer.setConstraintValue("top", 58);
        if (!videoInfoView.useDarkColor) {
            vbox_videoPlayer.setConstraintValue("backgroundColor", new int("0xFFFFFF"));
        } else {
            vbox_videoPlayer.setConstraintValue("backgroundColor", new int("0x646464"));
        }
        this.showStatusBar = true;
        this.videoPlayer.button_ChangeFullScreen.label = Message.L_FULL;
        if (this.videoInfoView.isHideUnderController) {
            showUnderController(false, false);
        } else {
            showUnderController(true, false);
        }
        if (this.videoInfoView.isHideTagArea) {
            showTagArea(false, false);
        } else {
            showTagArea(true, false);
        }

    }

    //ウィンドウの色の即時適応
    (this as Window).validateNow();

    Mouse.show();
    isMouseHide = false;

}

public function showUnderController(isShow: Boolean, isChangeWindowSize: Boolean = true): void {

    //下プレーヤを見せるか見せないか設定。
    if (!isShow) { //見せない
        (this.canvas_under as Canvas).height = 0;
        if (isChangeWindowSize) {
            this.nativeWindow.height = this.nativeWindow.height - 33;
        }
    } else { //見せる
        (this.canvas_under as Canvas).height = 33;
        if (isChangeWindowSize) {
            this.nativeWindow.height = this.nativeWindow.height + 33;
        }
    }

}

public function showTagArea(isShow: Boolean, isChangeWindowSize: Boolean = true): void {

    //タグ領域を見せるかどうかの設定
    if (!isShow) {	// 隠す
        (this.textArea_tag as TextArea).height = 0;
        vbox_videoPlayer.setConstraintValue("top", 0);
        if (isChangeWindowSize) {
            this.nativeWindow.height = this.nativeWindow.height - 50;
        }
    } else {	// 表示
        (this.textArea_tag as TextArea).height = 50;
        vbox_videoPlayer.setConstraintValue("top", 58);
        if (isChangeWindowSize) {
            this.nativeWindow.height = this.nativeWindow.height + 50;
        }
    }

}

private function keyUpListener(event: KeyboardEvent): void {
    if (event.keyCode == Keyboard.SPACE) {
        if (!(event.target is Button) && !(event.target is TextField)) {
            this.playerController.switchPlayer();
        }
    }
}

private function keyListener(event: KeyboardEvent): void {
//	trace(event.keyCode);
    if (event.keyCode == Keyboard.ESCAPE) {
        //Windowsだとこのイベントはキャッチされない？
        trace("ESC");
        if (this.videoInfoView.isHideUnderController) {
            showUnderController(false, false);
        } else {
            showUnderController(true, false);
        }
        if (this.videoInfoView.isHideTagArea) {
            showTagArea(false, false);
        } else {
            showTagArea(true, false);
        }

    } else if (event.keyCode == Keyboard.F11 ||
               (event.keyCode == Keyboard.F && (event.controlKey || event.commandKey))) {
//		trace("Ctrl + " + event.keyCode);
        this.changeFull();
    } else if (event.keyCode == Keyboard.I) {
        trace(event.keyCode + ":" + event);
        this.showVideoPlayerAndVideoInfoView();
    } else if (event.keyCode == Keyboard.LEFT) {
        //左キー。戻る
        if (event.target as UITextField) {
            return;
        }
        if (seekTimer != null) {
            seekTimer.stop();
        }
        seekTimer = new Timer(100, 1);
        seekTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function (event: Event): void {
            var newValue: Number = videoController.slider_timeline.value + seekValue;
            if (newValue <= (videoController.slider_timeline as HSlider).minimum) {
                newValue = 0;
            } else if (newValue >= (videoController.slider_timeline as HSlider).maximum) {
                newValue = (videoController.slider_timeline as HSlider).maximum;
            }
            trace(newValue + " = " + videoController.slider_timeline.value + "+" + seekValue);
            playerController.seek(newValue);
            seekValue = 0;
        });
        seekTimer.start();
        if (this.seekValue < this.videoInfoView.secondsToSeekOnKeyboard) {
            this.seekValue = 0;
        }
        else {
            this.seekValue -= this.videoInfoView.secondsToSeekOnKeyboard;
        }
    } else if (event.keyCode == Keyboard.RIGHT) {
        //右キー。進む。
        if (event.target as UITextField) {
            return;
        }
        if (seekTimer != null) {
            seekTimer.stop();
        }
        seekTimer = new Timer(100, 1);
        seekTimer.addEventListener(TimerEvent.TIMER_COMPLETE, function (event: Event): void {
            var newValue: Number = videoController.slider_timeline.value + seekValue;
            if (newValue <= (videoController.slider_timeline as HSlider).minimum) {
                newValue = 0;
            } else if (newValue >= (videoController.slider_timeline as HSlider).maximum) {
                newValue = (videoController.slider_timeline as HSlider).maximum;
            }
            trace(newValue + " = " + videoController.slider_timeline.value + "+" + seekValue);
            playerController.seek(newValue);
            seekValue = 0;
        });
        seekTimer.start();
        this.seekValue += this.videoInfoView.secondsToSeekOnKeyboard;
    } else if (event.keyCode == Keyboard.UP) {
        this.playerController.setVolume(this.videoController.slider_volume.value + 0.05);
    } else if (event.keyCode == Keyboard.DOWN) {
        this.playerController.setVolume(this.videoController.slider_volume.value - 0.05);
    }
}

public function rollOver(event: MouseEvent): void {
    this.videoController.resetAlpha(false);
    this.videoController.rollOver(event);
}

public function rollOut(event: MouseEvent): void {
    this.videoController.rollOut(event);
}

public function videoCanvasResize(event: ResizeEvent): void {
    this.playerController.windowResized(false);
}

private function readStore(): void {

    try {

        var confValue: String = ConfigManager.getInstance().getItem("isAlwaysFront");
        if (confValue == null) {
            //何もしない
        } else {
            isAlwaysFront = ConfUtil.parseBoolean(confValue);
        }

        //x,y,w,h

        confValue = ConfigManager.getInstance().getItem("playerWindowPosition_x");
        windowPosition_x = 0;
        if (confValue == null) {
            //何もしない
        } else {
            windowPosition_x = Number(confValue);
            this.addEventListener(FlexEvent.CREATION_COMPLETE, function (): void {
                nativeWindow.x = lastRect.x = windowPosition_x;
            });
        }

        confValue = ConfigManager.getInstance().getItem("playerWindowPosition_y");
        windowPosition_y = 0;
        if (confValue == null) {
            //何もしない
        } else {
            windowPosition_y = Number(confValue);
            this.addEventListener(FlexEvent.CREATION_COMPLETE, function (): void {
                nativeWindow.y = lastRect.y = windowPosition_y;
            });
        }

        confValue = ConfigManager.getInstance().getItem("playerWindowPosition_w");
        var windowPosition_w: Number = 0;
        if (confValue == null) {
            //何もしない
        } else {
            windowPosition_w = Number(confValue);
            this.addEventListener(FlexEvent.CREATION_COMPLETE, function (): void {
                nativeWindow.width = lastRect.width = windowPosition_w;
            });
        }

        confValue = ConfigManager.getInstance().getItem("playerWindowPosition_h");
        var windowPosition_h: Number = 0;
        if (confValue == null) {
            //何もしない
        } else {
            windowPosition_h = Number(confValue);
            this.addEventListener(FlexEvent.CREATION_COMPLETE, function (): void {
                nativeWindow.height = lastRect.height = windowPosition_h;
            });
        }

        confValue = ConfigManager.getInstance().getItem("windowSizeRatio");
        if (confValue == null) {
            //何もしない
        } else {
            nowRatio = Number(confValue);
        }

        confValue = ConfigManager.getInstance().getItem("isRepeat");
        if (confValue == null) {
            //何もしない
        } else {
            isRepeat = ConfUtil.parseBoolean(confValue);
        }

        confValue = ConfigManager.getInstance().getItem("isShowComment");
        if (confValue == null) {
            isShowComment = true;
        } else {
            isShowComment = ConfUtil.parseBoolean(confValue);
        }


    } catch (error: Error) {
        Alert.show(Message.M_CONF_FILE_IS_BROKEN, Message.M_ERROR);
        logManager.addLog(Message.FAIL_LOAD_CONF_FILE_FOR_VIDEO_PLAYER + ":" + Message.M_CONF_FILE_IS_BROKEN + ":" +
                          ConfigManager.getInstance().confFileNativePath + ":" + error);
        trace(error.getStackTrace());
    }

}

public function saveStore(): void {

    try {

        /*ローカルストアに値を保存*/
        ConfigManager.getInstance().removeItem("isAlwaysFront");
        ConfigManager.getInstance().setItem("isAlwaysFront", isAlwaysFront);

        ConfigManager.getInstance().removeItem("isRepeat");
        ConfigManager.getInstance().setItem("isRepeat", isRepeat.toString());

        ConfigManager.getInstance().removeItem("isShowComment");
        ConfigManager.getInstance().setItem("isShowComment", isShowComment.toString());

        // ウィンドウの位置情報保存
        ConfigManager.getInstance().removeItem("playerWindowPosition_x");
        ConfigManager.getInstance().setItem("playerWindowPosition_x", lastRect.x);

        ConfigManager.getInstance().removeItem("playerWindowPosition_y");
        ConfigManager.getInstance().setItem("playerWindowPosition_y", lastRect.y);

        ConfigManager.getInstance().removeItem("playerWindowPosition_w");
        ConfigManager.getInstance().setItem("playerWindowPosition_w", lastRect.width);

        ConfigManager.getInstance().removeItem("playerWindowPosition_h");
        ConfigManager.getInstance().setItem("playerWindowPosition_h", lastRect.height);

        ConfigManager.getInstance().removeItem("windowSizeRatio");
        ConfigManager.getInstance().setItem("windowSizeRatio", nowRatio);

        ConfigManager.getInstance().save();

        this.videoController.saveStore();

    } catch (error: Error) {
        Alert.show(Message.M_CONF_FILE_IS_BROKEN, Message.M_ERROR);
        logManager.addLog(Message.FAIL_SAVE_CONF_FILE_FOR_VIDEO_PLAYER + ":" + Message.M_CONF_FILE_IS_BROKEN + ":" +
                          ConfigManager.getInstance().confFileNativePath + ":" + error);
        EncryptedLocalStore.reset();
        trace(error.getStackTrace());
    }

}

/**
 * ニコ割領域を表示するかどうかを設定します
 * @param isShowNicowariArea
 *
 */
public function setShowAlwaysNicowariArea(isShowNicowariArea: Boolean): void {
    isNicowariShow = isShowNicowariArea;
    isResize = true;
    if (isNicowariShow == true && !videoInfoView.isNotPlayNicowari) {
        showNicowariArea();
    } else {
        hideNicowariArea();
    }
}

/**
 * ニコ割領域を表示します。
 *
 */
public function showNicowariArea(): void {
    if (canvas_nicowari != null && !videoInfoView.isNotPlayNicowari) {
        (canvas_nicowari as Canvas).height = int(PlayerController.NICO_WARI_HEIGHT);
    }
}

/**
 * ニコ割領域を隠します。
 *
 */
public function hideNicowariArea(): void {
    if (canvas_nicowari != null) {
        (canvas_nicowari as Canvas).height = 0;
    }
}


private function panelDoubleClicked(event: MouseEvent): void {
    isResize = true;
    if (isNicowariShow == false) {
        (canvas_nicowari as Canvas).height = int(PlayerController.NICO_WARI_HEIGHT);
        isNicowariShow = true;
    } else {
        (canvas_nicowari as Canvas).height = 0;
        isNicowariShow = false;
    }

    videoInfoView.setShowAlwaysNicowariArea(isNicowariShow);

}

private function updateComplete(): void {
    if (isResize) {
        isResize = false;
//		trace("updateComplete");
        playerController.windowResized(false);
    }
}

/**
 *
 * @param event
 *
 */
public function button_goToWebClicked(event: Event): void {
    this.playerController.watchOnWeb();
}

/**
 *
 * @param event
 *
 */
public function tweet(event: Event): void {
    this.playerController.tweet();
}

/**
 *
 * @param event
 *
 */
public function addHatenaBookmark(event: Event): void {
    this.playerController.addHatenaBookmark();
}

/**
 *
 * @param event
 *
 */
public function openNicoSound(event: Event): void {
    this.playerController.openNicoSound();
}

public function resetWindowPosition(): void {
    // ウィンドウの位置情報保存
    try {
        // ウィンドウの位置情報保存
        ConfigManager.getInstance().removeItem("playerWindowPosition_x");
        ConfigManager.getInstance().setItem("playerWindowPosition_x", "0");

        ConfigManager.getInstance().removeItem("playerWindowPosition_y");
        ConfigManager.getInstance().setItem("playerWindowPosition_y", "0");

        ConfigManager.getInstance().removeItem("playerWindowPosition_w");
        ConfigManager.getInstance().setItem("playerWindowPosition_w", "540");

        ConfigManager.getInstance().removeItem("playerWindowPosition_h");
        ConfigManager.getInstance().setItem("playerWindowPosition_h", "550");

        // 動画を開く　ウィンドウの位置初期化
        ConfigManager.getInstance().removeItem("videoSourceSelectWindow_x");
        ConfigManager.getInstance().setItem("videoSourceSelectWindow_x", 0);

        ConfigManager.getInstance().removeItem("videoSourceSelectWindow_y");
        ConfigManager.getInstance().setItem("videoSourceSelectWindow_y", 0);

        ConfigManager.getInstance().save();

        this.readStore();

    } catch (error: Error) {
        Alert.show(Message.M_CONF_FILE_IS_BROKEN, Message.M_ERROR);
        logManager.addLog(Message.FAIL_LOAD_CONF_FILE_FOR_VIDEO_PLAYER + ":" + Message.M_CONF_FILE_IS_BROKEN + ":" +
                          ConfigManager.getInstance().confFileNativePath + ":" + error);
        trace(error.getStackTrace());
    }

    if (this.nativeWindow != null && !(this as Window).closed) {
        this.nativeWindow.x = 0;
        this.nativeWindow.y = 0;

        this.width = 540;
        this.height = 550;
    }

}


private function resizeNow(event: ResizeEvent): void {
    isResize = true;
    if (videoController != null) {
        videoController.width = int(canvas_videoPlayer.width - canvas_videoPlayer.width / 4);
    }
    followInfoView(lastRect);
}

private function canvasVideoDroped(event: NativeDragEvent): void {
    if (event.clipboard.hasFormat(ClipboardFormats.TEXT_FORMAT) ||
        event.clipboard.hasFormat(ClipboardFormats.URL_FORMAT)) {
        var url: String = (event.clipboard.getData(ClipboardFormats.TEXT_FORMAT) as String);

        if (url == null) {
            url = (event.clipboard.getData(ClipboardFormats.URL_FORMAT) as String);
        }

        if (url == null || url == "null") {
            return;
        }

        var checker: ShortUrlChecker = new ShortUrlChecker();
        if (checker.isShortUrl(url)) {
            logManager.addLog("短縮URLを展開中...:" + url);
            checker.addEventListener(Event.COMPLETE, function (event: Event): void {
                var url: String = checker.url;
                logManager.addLog("短縮URLを展開:" + url);
                if (url.match(/https?:\/\/www\.nicovideo\.jp\/watch\/|file:\/\/\//)) {
                    playerController.playMovie(url);
                    return;
                }
                var videoId: String = PathMaker.getVideoID(url);
                if (videoId != null) {
                    url = "http://www.nicovideo.jp/watch/" + videoId;
                    playerController.playMovie(url);
                    return;
                }
            });
            checker.addEventListener(IOErrorEvent.IO_ERROR, function (event: Event): void {
                logManager.addLog(Message.M_SHORT_URL_EXPANSION_FAIL + ":" + event);
                Alert.show(Message.M_SHORT_URL_EXPANSION_FAIL, Message.M_ERROR);
            });
            checker.expansion(url);
        }

        if (url.match(/https?:\/\/www\.nicovideo\.jp\/watch\/|file:\/\/\//)) {
            playerController.playMovie(url);
            return;
        }
        var videoId: String = PathMaker.getVideoID(url);
        if (videoId != null) {
            url = "http://www.nicovideo.jp/watch/" + videoId;
            playerController.playMovie(url);
            return;
        }
    } else if (event.clipboard.hasFormat(ClipboardFormats.FILE_LIST_FORMAT)) {
        var array: Array = (event.clipboard.getData(ClipboardFormats.FILE_LIST_FORMAT) as Array);
        if (array != null && (array[0] as File).url.match(/https?:\/\/www\.nicovideo\.jp\/watch\/|file:\/\/\//)) {
            playerController.playMovie(array[0].url);
        }
    }
}

private function canvasVideoDragEnter(event: NativeDragEvent): void {
    if (event.clipboard.hasFormat(ClipboardFormats.TEXT_FORMAT) ||
        event.clipboard.hasFormat(ClipboardFormats.FILE_LIST_FORMAT) ||
        event.clipboard.hasFormat(ClipboardFormats.URL_FORMAT)) {
        NativeDragManager.acceptDragDrop(canvas_video);

//		if (event.allowedActions.allowCopy)
//		{
//			NativeDragManager.dropAction = NativeDragActions.COPY;
//		} else if (event.allowedActions.allowMove)
//		{
//			NativeDragManager.dropAction = NativeDragActions.MOVE;
//		} else if (event.allowedActions.allowLink)
//		{
        NativeDragManager.dropAction = NativeDragActions.LINK;
//		}

    }
}

public function setControllerEnable(isEnable: Boolean): void {
    if (this.nativeWindow != null && !this.closed) {
        if (videoController != null) {
            videoController.setControlEnable(isEnable);
        }
        if (videoController_under != null) {
            videoController_under.setControlEnable(isEnable);
        }
    }
}

private function changeShowInfoViewButtonClicked(event: MouseEvent): void {
    if (videoInfoView != null) {
        videoInfoView.visible = true;
    }
    showVideoPlayerAndVideoInfoView();
    (this.canvas_video_back as Canvas).setFocus();
}

private function changeFullButtonClicked(event: MouseEvent): void {
    if (this.playerController != null) {
        changeFull();
        (this.canvas_video_back as Canvas).setFocus();
    }
}

public function changeWideMode(event: Event): void {
    if (videoInfoView != null) {
        videoInfoView.changeWideMode();
    }
}

public function changeFullClickEventHandler(event: Event): void {
    changeFull();
}

/**
 * フルスクリーン/標準スクリーンを切り替えます
 *
 */
public function changeFull(): void {
    if (videoPlayer.stage.displayState == StageDisplayState.FULL_SCREEN_INTERACTIVE) {
        resetFull();
    } else {
        setFull();
    }
}

/**
 * ウィンドウをフルスクリーンにします
 *
 */
public function setFull(): void {
    this.videoPlayer.alwaysInFront = false;
    this.videoPlayer.button_ChangeFullScreen.label = Message.L_NORMAL;
    this.videoPlayer.showUnderController(false, false);
    this.videoPlayer.showTagArea(false, false);

//	this.videoPlayer.stage.fullScreenSourceRect = playerController.videoRectangle;	
    this.videoPlayer.stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
}


/**
 * ウィンドウのフルスクリーンを解除します
 *
 */
public function resetFull(): void {
    //フルスクリーン解除
    this.videoPlayer.stage.displayState = StageDisplayState.NORMAL;
    this.videoPlayer.button_ChangeFullScreen.label = Message.L_FULL;

    if (videoInfoView.isHideUnderController) {
        showUnderController(false, false);
    } else {
        showUnderController(true, false);
    }
    if (videoInfoView.isHideTagArea) {
        showTagArea(false, false);
    } else {
        showTagArea(true, false);
    }

    this.videoPlayer.alwaysInFront = this.videoPlayer.isAlwaysFront;
}

public function showAskToUserOnJump(open: Function, cancel: Function, videoId: String): void {
    _jumpDialog = PopUpManager.createPopUp(this, JumpDialog, true) as JumpDialog;
    _jumpDialog.setVideoId(videoId);
    PopUpManager.centerPopUp(_jumpDialog);
    _jumpDialog.addEventListener(Event.OPEN, function (event: Event): void {
        PopUpManager.removePopUp(_jumpDialog);
        open.call();
        _jumpDialog = null;
    });
    _jumpDialog.addEventListener(Event.CANCEL, function (event: Event): void {
        PopUpManager.removePopUp(_jumpDialog);
        cancel.call();
        _jumpDialog = null;
    });
}

public function enableMouseHide(): Boolean {
    if (_jumpDialog == null && isMouseHideEnable) {
        return true;
    } else {
        return false;
    }
}


private function mouseOverEventHandler(event: MouseEvent): void {

    isMouseHideEnable = true;

}

private function mouseOutEventHandler(event: MouseEvent): void {
    if (event.stageX == -1 && event.stageY == -1) {
        isMouseHideEnable = false;
    }
}

private function infoAreaLinkClicked(event: TextEvent): void {
    if (event.text.indexOf("mylist/") !== -1 || event.text.indexOf("channel/") !== -1 ||
        event.text.indexOf("community/") !== -1 || event.text.indexOf("user/") !== -1) {
//		trace(event.text);
        Application.application.renewMyList(event.text);
    } else if (event.text.indexOf("watch/") !== -1) {
        var videoId: String = PathMaker.getVideoID(event.text);
//		trace(videoId);
        playerController.playMovie("http://www.nicovideo.jp/watch/" + videoId);
    } else {
        trace(event);
    }
}

private function tagTextAreaLinkClikced(event: TextEvent): void {
    var word: String = String(event.text);
    Application.application.search(new SearchItem(word,
                                                  SearchSortString.convertSortTypeFromIndex(4),
                                                  NNDDSearchType.TAG,
                                                  word
    ));
}

private function changeShowCommentClickEventHandler(event: Event): void {
//	if(videoInfoView != null){
//		videoInfoView.changeShowComment();
//	}
//	isShowComment = !isShowComment;
    this.changeIsShowComment();
}

private function backClickEventHandler(event: Event): void {
    playerController.back();
}

private function backPlayListClickEventHandler(event: Event): void {
    playerController.next();
}

private function controlPlayListContextMenuDisplayHandler(event: Event): void {
    var contextMenuItem: ContextMenuItem = (event.currentTarget as ContextMenuItem);

    if (playerController.isPlayListPlaying) {
        contextMenuItem.enabled = true;
    } else {
        contextMenuItem.enabled = false;
    }
}

private function fileOpenClickEventHandler(event: Event): void {
    this.fileOpen();
}

public function get isFileOpenDialogFocusIn(): Boolean {
    if (this.videoSourceSelectWindow == null) {
        return false;
    }
    if (this.videoSourceSelectWindow.visible == false) {
        return false;
    }
    if (this.videoSourceSelectWindow.isTextInputFocusIn) {
        return true;
    } else {
        return false;
    }
}

public function fileOpen(): void {
    if (videoSourceSelectWindow != null && videoSourceSelectWindow.visible) {
        videoSourceSelectWindow.activate();
    } else {
        if (videoSourceSelectWindow != null) {
            videoSourceSelectWindow.close();
            videoSourceSelectWindow = null;
        }

        videoSourceSelectWindow = new VideoSourceSelectWindow();
        videoSourceSelectWindow.type = NativeWindowType.UTILITY;
        videoSourceSelectWindow.open(true);
    }
}

public function copyVideoUrl(event: Event): void {

    var videoId: String = PathMaker.getVideoID(this.title);

    if (videoId != null && videoId) {
        var url: String = "http://www.nicovideo.jp/watch/" + videoId;
        Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, url);
    }
}

public function copyVideoUrlWithTitle(event: Event): void {
    var videoId: String = PathMaker.getVideoID(this.title);

    if (videoId != null && videoId) {
        var str: String = this.title;
        if (str.indexOf("- [") != -1) {
            str = str.substr(0, str.indexOf("- ["));
        }

        str = str + " - http://www.nicovideo.jp/watch/" + videoId;
        Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, str);
    }
}

public function videoReload(event: Event): void {

    var videoId: String = PathMaker.getVideoID(this.title);

    if (videoId == null) {
        return;
    }

    playerController.reload(videoId);

}

public function updateFrameRate(): void {
    if (this.stage != null && videoPlayer.canvas_video != null) {
        if (videoInfoView.fps > 30) {
            videoPlayer.canvas_video.stage.frameRate = int(videoInfoView.fps);
        } else {
            videoPlayer.canvas_video.stage.frameRate = 30;
        }
        trace("stage.frameRate:" + videoPlayer.canvas_video.stage.frameRate);
    }
}
