package com.adobe.flashcatalyst.components
{

	import flash.display.AVM1Movie;
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.events.Event;
	
	import mx.controls.Image;
	import mx.core.MovieClipLoaderAsset;

	public class SWFController extends Image
	{
		public var autoStop:Boolean = true;
		
		public function SWFController()
		{
			super();
			
			addEventListener( Event.COMPLETE, handleComplete );
			
		}
			
		public function playSWF():void
		{
			var movieClip:MovieClip = getMovieClipFromImage();
			if( movieClip )
				movieClip.play();
		}
		
		public function stopSWF():void
		{
			var movieClip:MovieClip = getMovieClipFromImage();
			if( movieClip )
				movieClip.stop(); // stop at current frame
		}

		
		public function gotoAndPlaySWF( frame:int ):void
		{
			var movieClip:MovieClip = getMovieClipFromImage();
			if( movieClip )
				movieClip.gotoAndPlay( frame );
		}
		
		public function gotoFirstFrameAndStopSWF():void
		{
			var movieClip:MovieClip = getMovieClipFromImage();
			if( movieClip )
				movieClip.gotoAndStop(0); // go to first frame and stop
		}
		
		public function gotoAndStopSWF( frame:int ):void
		{
			var movieClip:MovieClip = getMovieClipFromImage();
			if( movieClip )
				movieClip.gotoAndStop( frame );
		}
		
					
		protected function getMovieClipFromImage() : MovieClip {
			var content:DisplayObject = this.content;
			
			if ( content is AVM1Movie ) {
				// can't control AVM1Movie
				return null;
			}
			else if( content is MovieClipLoaderAsset ){
				// Get child MovieClip from Loader
				if( DisplayObjectContainer(content).numChildren > 0 )
					content = Loader(DisplayObjectContainer(content).getChildAt(0)).content;
			}
			
			if( content is MovieClip )
				return MovieClip(content);
				
			return null;
		}
		
		private function handleComplete( event:Event ) : void {
			if( autoStop )
				SWFController(event.currentTarget).stopSWF();
		}
	}
}