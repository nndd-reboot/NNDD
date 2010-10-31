package org.mineap.nndd.downloadedList
{
	import flash.events.FileListEvent;
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	import mx.controls.DataGrid;
	import mx.controls.TileList;
	
	import org.mineap.nndd.LogManager;
	import org.mineap.nndd.library.ILibraryManager;
	import org.mineap.nndd.library.LibraryManagerBuilder;
	import org.mineap.nndd.model.NNDDVideo;
	import org.mineap.nndd.model.VideoType;
	import org.mineap.nndd.util.DateUtil;
	import org.mineap.nndd.util.PathMaker;

	/**
	 * DownloadedListManager.as
	 * ダウンロード済みアイテム表示用のリストを管理します。
	 * 
	 * @author shiraminekeisuke(MineAP)
	 * 
	 */	
	public class DownloadedListManager
	{
		private static const _downloadListManager:DownloadedListManager = new DownloadedListManager();
		
		private var sorceListArray:ArrayCollection;
		private var downloadedListArray:ArrayCollection;
		private var searchArray:ArrayCollection;
		private var libraryManager:ILibraryManager;
		
		public static const SORCE_ALL:int = 0;
		public static const SORCE_SINGLE_DOWNLOAD:int = 1;
		
		/**
		 * 
		 * @return 
		 * 
		 */
		public static function get instance():DownloadedListManager
		{
			return _downloadListManager;
		}
		
		/**
		 * コンストラクタ <br />
		 * このクラスはシングルトンパターンです。このクラスのインスタンスを取得する場合は DownloadedListManager#instance を使用して取得してください。
		 */
		public function DownloadedListManager()
		{
			if(_downloadListManager != null){
				throw new ArgumentError("DownloadedListManagerはインスタンス化できません");
			}
			this.libraryManager = LibraryManagerBuilder.instance.libraryManager;
		}
		
		/**
		 * 
		 * @param downloadedListArrayCollection
		 * 
		 */
		public function initialize(downloadedListArrayCollection:ArrayCollection):void
		{
			this.downloadedListArray = downloadedListArrayCollection;
		}
		
		
		/**
		 * ソースリストとダウンロード済みリストを最新の状態に更新します。
		 * 
		 * @param url 更新対象のディレクトリを示すurlです。
		 * @param showSubDirItem
		 * 
		 */
		public function updateDownLoadedItems(url:String, showSubDirItem:Boolean):void{
			
			updateDownloadedListItems(url, showSubDirItem);
			
		}
		
		/**
		 * ダウンロード済みリストを最新の状態に更新します。
		 * @param sorceIndex
		 * @param showSubDirItem
		 */
		public function updateDownloadedListItems(url:String, showSubDirItem:Boolean):void{
			this.downloadedListArray.removeAll();
			if(url == null){
				url = libraryManager.libraryDir.url;
			}
			var myFile:File = new File(url);
			var sorceType:int = 0;
			if(-1 == myFile.url.indexOf(libraryManager.libraryDir.url)){
				sorceType = 2;
			}
			addDownLoadedItems(myFile, false, showSubDirItem);
		}
		
		/**
		 * 指定されたディレクトリ下にある動画をダウンロード済みリストに追加します。<br />
		 * searchDirをtrueに設定すると実際にディレクトリを探索し、存在するファイルを一覧に追加します。<br />
		 * falseを指定した場合はライブラリファイルで管理済みの項目のみを一覧に追加します。こちらの動作はオンメモリのみの処理なため、一覧への追加が早く終了します。<br />
		 * 
		 * @param saveDir 探索するディレクトリ
		 * @param searchDir 指定されたディレクトリを毎回探索するかどうか
		 * @param showSubDirItem サブディレクトリの項目を表示するかどうか
		 */
		public function addDownLoadedItems(saveDir:File, searchDir:Boolean = false, showSubDirItem:Boolean = false):void{

			this.downloadedListArray.addItem({
				dataGridColumn_thumbImage: "",
				dataGridColumn_videoName: "loading...",
				dataGridColumn_date: "",
				dataGridColumn_count: "",
				dataGridColumn_videoPath: "",
				dataGridColumn_condition: ""
			});

			if(searchDir){
				
				// ディレクトリを探索するモード
				saveDir.addEventListener(FileListEvent.DIRECTORY_LISTING, directoryListingEventHandler, false, 0, true);
				saveDir.getDirectoryListingAsync();
				
			}else{
				
				// ライブラリファイルから探索するモード
				var nnddVideos:Vector.<NNDDVideo> = libraryManager.getNNDDVideoArray(saveDir, showSubDirItem);
				
				nnddVideos.sort(function compare(x:NNDDVideo, y:NNDDVideo):Number {
					var xName:String = x.getDecodeUrl();
					var yName:String = y.getDecodeUrl();
					if(xName != null && yName != null){
						return xName.localeCompare(yName);
					}else{
						return 0;
					}
				});
				
				this.downloadedListArray.removeAll();
				nnddVideos.forEach(callback);
				
				LogManager.instance.addLog("動画を表示:" + saveDir.nativePath + ":" + nnddVideos.length);
				
			}
		}
		
		/**
		 * 
		 * @param event
		 * 
		 */
		private function callback(video:NNDDVideo, index:int, vector:Vector.<NNDDVideo>):void{
			
			var decodedUrl:String = decodeURIComponent(video.getDecodeUrl());
			var status:String = "";
			var thumbUrl:String = "";
			var playCount:Number = 0;
			var creationDate:Date = null;
		
			thumbUrl = video.thumbUrl;
			playCount = video.playCount;
			creationDate = video.creationDate;
			if(video.isEconomy){
				status = "エコノミー画質";
			}
			
			if(thumbUrl == ""){
				var videoId:String = PathMaker.getVideoID(decodedUrl);
				if(videoId != null){
					thumbUrl = PathMaker.getThumbImgUrl(videoId);
				}
			}
			
			this.downloadedListArray.addItem({
				dataGridColumn_thumbImage: thumbUrl,
				dataGridColumn_videoName: decodedUrl.substring(decodedUrl.lastIndexOf("/")+1),
				dataGridColumn_date: DateUtil.getDateString(creationDate),
				dataGridColumn_count: playCount,
				dataGridColumn_videoPath: decodedUrl,
				dataGridColumn_condition: status
			});
			
		}
		
		/**
		 * 
		 * @param event
		 * 
		 */
		private function directoryListingEventHandler(event:FileListEvent):void{
			var fileList:Array = event.files;
			var targetFileList:Vector.<File> = new Vector.<File>();
//			var targetFileList:Array = new Array();
			
			(event.currentTarget as File).removeEventListener(FileListEvent.DIRECTORY_LISTING, directoryListingEventHandler);
			
			var oldDate:Date = new Date();
			var newDate:Date = new Date();
			trace("fileList.length:" + fileList.length);
			trace(newDate.getTime() - oldDate.getTime() + " ms");
			oldDate = newDate;
			
			var fileListLen:int = fileList.length;
			var file:File = null;
			var extension:String = null;
			var fileIndex:int = 0;
			for(var index:int = 0; index<fileListLen; index++){
				
				file = File(fileList[index]);
				
//				if(!file.isDirectory){
					extension = file.extension;
					if(extension != null){
						extension = extension.toLocaleLowerCase();
						if(extension == VideoType.XML_S || extension == VideoType.HTML_S
								|| extension == VideoType.JPEG_S){
							fileIndex++;
						}else if(extension == VideoType.FLV_S || extension == VideoType.MP4_S){
							
							targetFileList[fileIndex] = file;
							fileIndex++;
							
						}else if(extension == VideoType.SWF_S){
							if(file.nativePath.indexOf(VideoType.NICOWARI) == -1){
								targetFileList[fileIndex] = file;
								fileIndex++;
							}
							
						}
					}
//				}
				
			}
			
			
			newDate = new Date();
			trace("targetFileList.length:" + targetFileList.length);
			trace(newDate.getTime() - oldDate.getTime() + " ms");
			oldDate = newDate;
			
			this.downloadedListArray.removeAll();
			
			for(var i:int = 0; i<targetFileList.length; i++){
				
				var myFile:File = targetFileList[i];
				
				if(myFile.exists){
					
					var decodedUrl:String = decodeURIComponent(myFile.url);
					var video:NNDDVideo = libraryManager.isExist(PathMaker.getVideoID(decodedUrl));
					var status:String = "";
					var thumbUrl:String = "";
					var playCount:Number = 0;
					var creationDate:Date = null;
					
					if(video != null){
						thumbUrl = video.thumbUrl;
						playCount = video.playCount;
						creationDate = video.creationDate;
						if(video.isEconomy){
							status = "エコノミー画質";
						}
					}
					
					if(thumbUrl == ""){
						thumbUrl = PathMaker.createThumbImgFilePath(decodedUrl, true);
					}
					if(creationDate == null){
						creationDate = myFile.creationDate;
					}
					
					this.downloadedListArray.addItem({
						dataGridColumn_thumbImage: thumbUrl,
						dataGridColumn_videoName: decodedUrl.substring(decodedUrl.lastIndexOf("/")+1),
						dataGridColumn_date: DateUtil.getDateString(creationDate),
						dataGridColumn_count: playCount,
						dataGridColumn_videoPath: decodedUrl,
						dataGridColumn_condition: status
					});
					
				}
				
			}
			
			newDate = new Date();
			trace(newDate.getTime() - oldDate.getTime() + " ms");
			oldDate = newDate;
				
		}
		
		
		/**
		 * 引数で渡されたファイルがすでにダウンロード済みリストに存在するかどうかを判定する。
		 * @param filePath　判定したいファイルのアドレス。File.urlに格納されている文字列を渡す。
		 * @return 存在する場合はTrue
		 * 
		 */
		private function isListAddedItem(filePath:String):Boolean
		{
			try{
				for(var index:int = 0; index < this.downloadedListArray.length; index++){
					var path:String = this.downloadedListArray.getItemAt(index).dataGridColumn_videoPath.toString;
					
					if(filePath.indexOf(path) != -1){
						return true;
					}
				}
			}catch(error:Error){}
			
			return false;
		}
		
		/**
		 * 現在表示しているダウンロード済みリスト内から引数で指定された文字列に該当する動画名の動画を探し、
		 * リストに表示します。<br>
		 * 長さが0以下の文字列を引数に渡すと、初期状態のリストを表示します。
		 * 
		 * @param dataGrid
		 * @param tileList
		 * @param word
		 * 
		 */
		public function searchAndShow(dataGrid:DataGrid, tileList:TileList, word:String):void{
			
			if(word.length > 0){
				
				if(downloadedListArray.length > 0 && downloadedListArray[0].dataGridColumn_videoName != "loading..." ){
					//wordをスペースで分割
					var pattern:RegExp = new RegExp("\\s*([^\\s]*)", "ig");
					var array:Array = word.match(pattern);
					
					this.searchArray = null;
					this.searchArray = new ArrayCollection();
					
					var iSize:int = dataGrid.dataProvider.length;
					for(var i:uint = 0; i < iSize ; i++ ){
						var existCount:int = 0;
						
						var jSize:int = array.length;
						for(var j:uint = 0; j<jSize; j++){
							if(j < 1){
								if(String(dataGrid.dataProvider[i].dataGridColumn_videoName).toUpperCase().indexOf(String(array[j]).toUpperCase()) != -1){
									existCount++;
								}
							}else if(array[j] != " "){
								var tempWord:String = (array[j] as String).substring(1);
								if(String(dataGrid.dataProvider[i].dataGridColumn_videoName).toUpperCase().indexOf(String(tempWord).toUpperCase()) != -1){
									existCount++;
								}
							}else{
								existCount++;
							}
						}
						if(existCount >= jSize){
							searchArray.addItem({
								dataGridColumn_thumbImage:downloadedListArray[i].dataGridColumn_thumbImage,
								dataGridColumn_videoName:dataGrid.dataProvider[i].dataGridColumn_videoName,
								dataGridColumn_date:dataGrid.dataProvider[i].dataGridColumn_date,
								dataGridColumn_condition:dataGrid.dataProvider[i].dataGridColumn_condition,
								dataGridColumn_count:dataGrid.dataProvider[i].dataGridColumn_count,
								dataGridColumn_videoPath:dataGrid.dataProvider[i].dataGridColumn_videoPath,
								dataGridColumn_nicoVideoUrl: dataGrid.dataProvider[i].dataGridColumn_nicoVideoUrl
							});
						}
					}
					
					dataGrid.dataProvider = searchArray;
					
				}else{
					
					dataGrid.dataProvider = null;
					
				}
				
			}else{
				if(tileList.selectedItems.length == 0){
					this.searchArray = null;
					dataGrid.dataProvider = downloadedListArray;
				}else{
					searchAndShowByTag(dataGrid, tileList.selectedItems);
				}
			}
			
		}
		
		/**
		 * 
		 * @param tags
		 * @return 
		 * 
		 */
		public function searchAndShowByTag(dataGrid:DataGrid, tags:Array):void{
			if(tags.length > 0 && tags[0] != "すべて" ){
				
				this.searchArray = null;
				this.searchArray = new ArrayCollection();
				
				var iSize:int = downloadedListArray.length;
				for(var i:int = 0; i < iSize; i++ ){
					var existCount:int = 0;
					var videoName:String = downloadedListArray[i].dataGridColumn_videoName;
					var videoId:String = PathMaker.getVideoID(videoName);
					
					var jSize:int = tags.length;
					for(var j:uint = 0; j<jSize; j++){
						
						var video:NNDDVideo = libraryManager.isExist(videoId);
						if(video != null){
							
							var kSize:int = video.tagStrings.length;
							for(var k:uint = 0; k<kSize; k++){
								if(String(video.tagStrings[k]).toUpperCase().indexOf(String(tags[j]).toUpperCase()) != -1){
									existCount++;
								} 
							}
							
						}
					}
					if(existCount >= jSize){
						searchArray.addItem({
							dataGridColumn_thumbImage:downloadedListArray[i].dataGridColumn_thumbImage,
							dataGridColumn_videoName:downloadedListArray[i].dataGridColumn_videoName,
							dataGridColumn_date:downloadedListArray[i].dataGridColumn_date,
							dataGridColumn_condition:downloadedListArray[i].dataGridColumn_condition,
							dataGridColumn_count:downloadedListArray[i].dataGridColumn_count,
							dataGridColumn_videoPath:downloadedListArray[i].dataGridColumn_videoPath,
							dataGridColumn_nicoVideoUrl: downloadedListArray[i].dataGridColumn_nicoVideoUrl
						});
					}
				}
				
				dataGrid.dataProvider = searchArray;
			}else{
				this.searchArray = null;
				dataGrid.dataProvider = downloadedListArray;
			}
		}
		
		/**
		 * 引数で指定されたインデックスに該当する動画に対する絶対パスを返します。
		 * @param selectedIndex
		 * @return インデックスに該当するダウンロード済みリストの動画の絶対パス
		 * 
		 */
		public function getVideoPath(selectedIndex:int):String{
			if(this.searchArray != null){
				if(searchArray.length > selectedIndex){
					return searchArray[selectedIndex].dataGridColumn_videoPath;
				}else{
					return null;
				}
				
			}else{
				if(downloadedListArray.length > selectedIndex){
					return downloadedListArray[selectedIndex].dataGridColumn_videoPath;
				}else{
					return null;
				}
			}
		}
		
		/**
		 * 表示中の項目をリフレッシュします。
		 * 
		 */
		public function refresh():void{
			if(this.downloadedListArray != null){
				this.downloadedListArray.refresh();
			}
			if(this.searchArray != null){
				this.searchArray.refresh();
			}
		}
		
	}
}