/* AS3
	Copyright 2011 TokBox.
*/
package components 
{
	
	import flash.display.DisplayObject;
	
	import mx.core.UIComponent;

	/**
	 *	Contains a video object and sets its size
	 *
	 *	@langversion ActionScript 3.0
	 *	@playerversion Flash 10.0
	 *
	 *	@author Adam Ullman
	 *	@since  17.04.2011
	 */
	public class VideoContainer extends UIComponent 
	{
		
		override public function removeChild(child:DisplayObject) : DisplayObject 
		{
			var res:DisplayObject = super.removeChild(child);
			
			if (numChildren == 0) {
				parent.removeChild(this);
			}
			
			return res;
		}

		/**
		 *	@private
		 */
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number) : void
		{
			super.updateDisplayList(unscaledWidth, unscaledHeight);
			
			if (numChildren == 1) {
				var child:DisplayObject = getChildAt(0);
				child.width = unscaledWidth;
				child.height = unscaledHeight;
			}
		}
	}
	
}
