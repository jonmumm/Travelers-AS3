package filters
{
	import spark.filters.DropShadowFilter;
	
	public class ButtonDropShadowFilter extends DropShadowFilter
	{
		public function ButtonDropShadowFilter(distance:Number=4.0, angle:Number=45, color:uint=0, alpha:Number=1.0, blurX:Number=4.0, blurY:Number=4.0, strength:Number=1.0, quality:int=1, inner:Boolean=false, knockout:Boolean=false, hideObject:Boolean=false)
		{
			super(distance, angle, color, alpha, blurX, blurY, strength, quality, inner, knockout, hideObject);
			
			// Set properties we want for bilter
			this.angle = 75;
			this.blurX = 15;
			this.blurY = 15;
		
		}
	}
}