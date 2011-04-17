/* (c) 2007-2009, TokBox, All Rights Reserved. */

package components
{
	import flash.display.DisplayObject;
	import flash.events.MouseEvent;
	
	import mx.containers.Canvas;
	import mx.core.UIComponent;
	import mx.effects.Effect;
	import mx.effects.Move;
	import mx.effects.Parallel;
	import mx.effects.Resize;
	import mx.events.ResizeEvent;
	import mx.logging.ILogger;
	import mx.logging.Log;
	import mx.events.FlexEvent;
	
	
	[Event(name="addFriend", type="com.tokbox.call.events.CallParticipantEvent")]
	
	/**
	 * Extend the VideoBox tile layout to support a bigChild layout where the
	 * bigChild occupies as much available space keeping the aspect ratio, and remaining
	 * children are adjusted in the remaining space.
	 */
	public class VideoBoxAnimated extends Canvas
	{
		
		//--------------------------------------
		// CLASS CONSTANTS
		//--------------------------------------
	
		// if bigChild is present, then minimum dimensions of the PIP or small child.
		private static const MIN_HEIGHT:uint = 60;
		private static const MIN_WIDTH:uint = 80;
		private static const UNDOCK_DEFAULT_WIDTH:uint = 120;
		private static const UNDOCK_DEFAULT_HEIGHT:uint = 90;
		
		private static const EFFECT_DURATION:uint = 500;
		private static const MIN_CHANGE_TIME:uint = 100;
		
		//--------------------------------------
		// PRIVATE VARIABLES
		//--------------------------------------
		
		// currently playing effects
		private var effects:Array = new Array();
		
		// co-ordinates before drag. indexed by child. value is Coordinate object.
		private var coord:Object = new Object();
		
		// whether drag is enabled or not? indexed by child
		private var drags:Object = new Object();
		
		// position of the configuration
		private var x0:uint = 0, y0:uint = 0, optCol:uint = 1;
		
		// the current bigChild. Null means pure TILE mode.
		private var _bigChild:DisplayObject = null;
		
		// the layout object for this box
		private var pos:Position = new Position(1, 1, 1, 1, 0, 0, 0, 0, 0, 0, true);
		
		// we don't do animation if boxes are added/removed in quick succession.
		private var lastChange:Date = new Date();
		
		// Spacing between boxes, same as horizontal and vertical gaps.
		protected var _spacing:int = 1;
		
		// Margins (vertical and horizontal) same as inside padding of VideoBox
		protected var _margin:int = 0;
		
		private var _created : Boolean = false;
		
		//--------------------------------------
		// CONSTRUCTOR
		//--------------------------------------
		
		public function VideoBoxAnimated()
		{
			trace("VideoBoxAnimated() called");
			verticalScrollPolicy = horizontalScrollPolicy = "off";
			styleName = "videoBox";
			addEventListener(ResizeEvent.RESIZE, resizeHandler, false, 0, true);
			addEventListener(FlexEvent.CREATION_COMPLETE, createdHandler, false, 0, true);
		}
		
		//--------------------------------------
		// GETTERS/SETTERS
		//--------------------------------------
		
		[Bindable]
		/**
		 * Update the bigChild property of the box container.
		 */
		public function get bigChild():DisplayObject
		{
			return _bigChild;
		}
		public function set bigChild(value:DisplayObject):void
		{
			var oldValue:DisplayObject = _bigChild;
			_bigChild = value;
			if (oldValue != value) {
				trace("bigChild " + oldValue + "=>" + value);
				if (oldValue == null) {
					// change big-child to top in z-index
					if (contains(value) && getChildIndex(value) != this.numChildren - 1) {
						setChildIndex(value, this.numChildren - 1);
					}
				}
				else if (value == null) {
					// change old big-child to top in z-index
					if (contains(oldValue) && getChildIndex(oldValue) != this.numChildren - 1) {
						setChildIndex(oldValue, this.numChildren - 1);
					}
				}
				else {
					// switch the bigChild and old bigChild z-index, and make bigChild as top
					if (contains(oldValue) && contains(value))
						setChildIndex(oldValue, getChildIndex(value));
					if (contains(value) && getChildIndex(value) != this.numChildren - 1) {
						setChildIndex(value, this.numChildren - 1);
					}
				}
				if (value == null || contains(value)) {
					calculatePosition(this.numChildren);
					updateBoxes();
				}
			}
		}
		
		public function get created() : Boolean 
		{ 
			return _created; 
		}
		
		[Bindable(event="numChildrenChanged")]
		override public function get numChildren() : int 
		{
			return super.numChildren;
		}
		
		//--------------------------------------
		// PUBLIC METHODS
		//--------------------------------------
		
		override public function addChild(child:DisplayObject):DisplayObject
		{
			return addChildInternal(child, numChildren);
		}
		override public function addChildAt(child:DisplayObject, index:int):DisplayObject
		{
			return addChildInternal(child, index);
		}
		override public function removeChild(child:DisplayObject):DisplayObject
		{
			return removeChildInternal(getChildIndex(child));
		}
		override public function removeChildAt(index:int):DisplayObject
		{
			return removeChildInternal(index);
		}
		override public function removeAllChildren():void
		{
			removeAllChildrenInternal();
		}
		
		// does nothing here
		public function refresh():void
		{
			trace("refresh() ignored");
		}
	
		/**
		 * Replace an existing child with the new one. This is typically used for replacing an InviteView with
		 * a RemoteVideoView when the remote party accepts the call. If the oldChild is not found in the children
		 * list, then it just appends the newChild at the end.
		 */
		public function replaceChild(oldChild:DisplayObject, newChild:DisplayObject):void
		{	
			var index:int = this.getChildIndex(oldChild);
			trace("replaceChild old=" + oldChild + " new=" + newChild + " index=" + index);
			if (oldChild != newChild) {
				if (index >= 0) {
					newChild.x = oldChild.x;
					newChild.y = oldChild.y;
					newChild.width = oldChild.width;
					newChild.height = oldChild.height;
					if (newChild is UIComponent) 
						UIComponent(newChild).doubleClickEnabled = true;
						
					newChild.addEventListener(MouseEvent.DOUBLE_CLICK, doubleClickHandler, false, 0, true);
					newChild.addEventListener(MouseEvent.MOUSE_DOWN, mouseDownHandler, false, 0, true);
					newChild.addEventListener(MouseEvent.MOUSE_UP, mouseUpHandler, false, 0, true);
					newChild.addEventListener(MouseEvent.ROLL_OVER, rollOverHandler, false, 0, true);
					newChild.addEventListener(MouseEvent.ROLL_OUT, rollOutHandler, false, 0, true);
					oldChild.removeEventListener(MouseEvent.DOUBLE_CLICK, doubleClickHandler);
					oldChild.removeEventListener(MouseEvent.MOUSE_DOWN, mouseDownHandler);
					oldChild.removeEventListener(MouseEvent.MOUSE_UP, mouseUpHandler);
					oldChild.removeEventListener(MouseEvent.ROLL_OVER, rollOverHandler);
					oldChild.removeEventListener(MouseEvent.ROLL_OUT, rollOutHandler);
			
					super.removeChild(oldChild);
					super.addChildAt(newChild, index);
					if (_bigChild == oldChild) { // don't use bigChild, but use _bigChild.
						_bigChild = newChild;
					}	
				}
				else {
					this.addChild(newChild);
				}
			}
		}
		
		/** 
		 * Print the change in positions if any.
		 */
		override public function setChildIndex(child:DisplayObject, index:int):void
		{
			trace("setChildIndex " + child + " " + index);
			super.setChildIndex(child, index);
		}
		
		//--------------------------------------
		// PRIVATE METHODS
		//--------------------------------------
		
		private function addChildInternal(child:DisplayObject, index:int):DisplayObject
		{
			if (!(child is UIComponent)) {
				var container:UIComponent = new VideoContainer();
				container.addChild(child);
				child = container;
			}
			trace("addChildInternal child=" + child + " index=" + index);
			 
			// calculate new optimal positions
			calculatePosition(this.numChildren + 1);
			
			child.width = pos.width;
			child.height = pos.height;
			
			if (child is UIComponent)
				UIComponent(child).doubleClickEnabled = true;
			child.addEventListener(MouseEvent.DOUBLE_CLICK, doubleClickHandler, false, 0, true);
			child.addEventListener(MouseEvent.MOUSE_DOWN, mouseDownHandler, false, 0, true);
			child.addEventListener(MouseEvent.MOUSE_UP, mouseUpHandler, false, 0, true);
			child.addEventListener(MouseEvent.ROLL_OVER, rollOverHandler, false, 0, true);
			child.addEventListener(MouseEvent.ROLL_OUT, rollOutHandler, false, 0, true);
			child.addEventListener(FlexEvent.UPDATE_COMPLETE, childUpdateHandler, false, 0, true);
			
			var result:DisplayObject = super.addChildAt(child, index);

			if (bigChild == child) { // bigChild was set before invoking addChild
				if (getChildIndex(child) != this.numChildren - 1) {
					setChildIndex(child, this.numChildren - 1);
				}
			}
			
			updateBoxes(numChildren > 2);
			updateLastChange();
			
			dispatchEvent(new Event("numChildrenChanged"));
			
			return result;
		}
		
		private function removeChildInternal(index:int):DisplayObject
		{
			var child:DisplayObject = getChildAt(index);
			trace("removeChildInternal child=" + child + " index=" + index);

			var result:DisplayObject = super.removeChild(child);
			if (child == bigChild) {
				_bigChild = null;
			}
			
			child.removeEventListener(MouseEvent.DOUBLE_CLICK, doubleClickHandler);
			child.removeEventListener(MouseEvent.MOUSE_DOWN, mouseDownHandler);
			child.removeEventListener(MouseEvent.MOUSE_UP, mouseUpHandler);
			child.removeEventListener(MouseEvent.ROLL_OVER, rollOverHandler);
			child.removeEventListener(MouseEvent.ROLL_OUT, rollOutHandler);
			
			calculatePosition(this.numChildren);
			updateBoxes(numChildren > 1);
			updateLastChange();
			
			dispatchEvent(new Event("numChildrenChanged"));
			
			return result;
		}
		
		private function removeAllChildrenInternal():void
		{
			trace("removeAllChildrenInternal()");
			super.removeAllChildren();
		}
		
		/*
		 * Find the best layout for the given number of children (count) in a space of size
		 * (wr, hr). It returns [wn, hn, cols] indicating dimension of individual child
		 * (wn, hn) and the number of columns in the tile.
		 */
		private function findBestLayout(wr:Number, hr:Number, count:int):Layout
		{
			var col:int = 1, row:int = 1;
			var wn:int = 0, hn:int = 0;
			var remSpace:int = wr*hr; // minimum remaining space.
			
			// a special case of unoptimized layout is two party call
			if (count == 2 && wr >= hr) {
				col = 2; 
				row = 1;
				wn = Math.min((hr/row)*(4.0/3.0), (wr / col));;
				hn = Math.min((hr/row), (wr/col)*(3.0/4.0));
				return new Layout(col, row, wn, hn);
			}
			
			// iterate over all column values and find the best.
			for (var c:int=1; c <= count; ++c) {
				var r:int = int(Math.ceil(count/c)); // rows
				var w:Number = Math.min((hr/r)*(4.0/3.0), (wr/c));
				var h:Number = Math.min((hr/r), (wr/c)*(3.0/4.0));
				var space:Number = wr*hr - count*(w*h);
				if (space <= remSpace) { // use <= instead < so that row is preferred over column
					remSpace = space;
					col = c;
					row = r;
					wn = w;
					hn = h;
				}
			}
			return new Layout(col, row, wn, hn);
		}
		
		private function calculatePosition(count:uint):void
		{
			var ratio:Number = 3/4; // height/width aspect ratio inverse
			var layout:Layout; // layout for non-bigChild children
			
			if (count <= 0) { //corner case
				pos.update(1, 1, 1, 1, 0, 0, 0, 0, 0, 0, true);
				return;
			}
			
			if (bigChild != null) {
				// first calculate position of bigChild
				var h1:Number = Math.min(this.height, this.width*ratio); // maximum height of bigChild?
				var w1:Number = h1/ratio; // corresponding width
				var hr:Number = this.height - h1; // remaining height
				var wr:Number = this.width - w1;  // remaining width
				
				// if no space available either on right or bottom. Then assume on right, 
				// by reducing the width of w1, instead of doing picture in picture
				if (hr < MIN_HEIGHT && wr < MIN_WIDTH) {
					wr = MIN_WIDTH;
					w1 = this.width - wr;
					hr = 0;
					h1 = w1*ratio;
				}
				
				// calculate the best layout of the remaining children.
				layout = (hr > MIN_HEIGHT ? findBestLayout(this.width-2*_margin+_spacing, hr-2*_margin+_spacing, count-1) : findBestLayout(wr-2*_margin+_spacing, this.height-2*_margin+_spacing, count-1));
				
				// we need to horizontally center, and vertically top the views if bigChild is present
				var xoff:int = _margin;
				var yoff:int = _margin;
				
				if (hr < MIN_HEIGHT) {
					var wtotal:int = w1 + layout.width*layout.col
					xoff += (this.width - wtotal) / 2;	
				}
				
				pos.update(layout.col, layout.row, layout.width, layout.height, xoff, yoff, w1+_spacing, h1+_spacing, wr, 0, hr > MIN_HEIGHT);
			}
			else {
				layout = findBestLayout(this.width-2*_margin+_spacing, this.height-2*_margin+_spacing, count);
				
				var x0:uint = this.width/2 - (layout.width * layout.col)/2 + _margin;
				var y0:uint = this.height/2 - (layout.height * layout.row)/2 + _margin;
				
				pos.update(layout.col, layout.row, layout.width, layout.height, x0, y0, 0, 0, 0, 0, true);
			}
		}
		
		private function getChildPosition(index:int, count:int):Object
		{
			var result:Object = {x: 0, y: 0};
			var col:int = index % pos.col;
			var row:int = Math.floor(index / pos.col);
			if (bigChild == null) {
				result.x = pos.x0 + col * pos.width;
				result.y = pos.y0 + row * pos.height;
				if ((pos.row*pos.col-index) <= pos.col) {
					result.x += ((pos.row*pos.col-count) % pos.col)*pos.width/2;
				}
			}
			else {
				result.x = pos.x0 + col * pos.width;
				result.y = (pos.isRight ? pos.bheight : 0) + pos.y0 + row * pos.height;
			}
			return result;
		}
		
		private function updateBoxes(animate:Boolean=true):void
		{
			stopEffects();
			
			var effect:Parallel, resize:Resize, move:Move;
			
			// first position the bigChild
			if (bigChild != null) {
				if (bigChild.width != pos.bwidth || bigChild.height != pos.bheight
				|| bigChild.x != (pos.bx0 + pos.x0) || bigChild.y != (pos.by0 + pos.y0)) {
					effect = new Parallel(bigChild);
					effect.duration = EFFECT_DURATION;
					resize = new Resize();
					resize.widthTo = pos.bwidth - _spacing;
					resize.heightTo = pos.bheight - _spacing;
					move = new Move();
					move.xTo = pos.bx0 - pos.x0;
					move.yTo = pos.by0 + pos.y0;
					effect.addChild(resize);
					effect.addChild(move);
					effect.play();
					effects.push(effect);
				}
			}

			var index:int = 0;
			for (var i:int=0; i<this.numChildren; ++i) {
				var c:DisplayObject = this.getChildAt(i);
				if (c == bigChild) // ignore bigChild now
					continue; 
					
				var xy:Object = getChildPosition(index, this.numChildren);
				index++;
				
				if (c.width != pos.width || c.height != pos.height || c.x != xy.x || c.y != xy.y) {
					if (animate) {
						effect = new Parallel(c);
						effect.duration = EFFECT_DURATION;
						resize = new Resize();
						resize.widthTo = pos.width - _spacing;
						resize.heightTo = pos.height - _spacing;
						move = new Move();
						move.xTo = xy.x;
						move.yTo = xy.y;
						effect.addChild(resize);
						effect.addChild(move);
						effect.play();
						effects.push(effect);
					} else {
						c.width = pos.width - _spacing;
						c.height = pos.height - _spacing;
						c.x = xy.x;
						c.y = xy.y;
					}
				}
			}
		}
		
		private function resizeHandler(event:ResizeEvent):void
		{
			trace("resizeHandler old=" + event.oldWidth + "x" + event.oldHeight + " new=" + this.width + "x" + this.height);
			if (Math.abs(event.oldWidth - this.width) > 1 || Math.abs(event.oldHeight - this.height) > 1) {
				calculatePosition(this.numChildren);
				updateBoxes(numChildren > 2);
			}
		}
		
		private function createdHandler(event:FlexEvent) : void 
		{
			_created = true;
			
			removeEventListener(event.type, createdHandler);
		}
		
		private function stopEffects():void
		{
			for each (var effect:Effect in effects) {
				effect.end();
			}
			effects.splice(0, effects.length);
		}
		
		private function mouseDownHandler(event:MouseEvent):void
		{
			var target:UIComponent = event.currentTarget as UIComponent;
			if (target != null) {
				// setChildIndex causes the child to be z-indexed correctly, but disturbs our order of 
				// child index values and hence the position in the tile
				var index:int = this.getChildIndex(target);
				stopEffects();
				if (index < this.numChildren - 1)
					this.setChildIndex(target, this.numChildren - 1);
				// move the child		
				coord[target] = new Coordinate(target.x, target.y, index);
				
				target.startDrag();
			}
		}
		
		private function mouseUpHandler(event:MouseEvent):void
		{
			var target:UIComponent = event.currentTarget as UIComponent;
			if (target != null) {
				target.stopDrag();
				
				if (target in coord) {
					stopEffects();
					
					if (target in coord) {
						// move in docked
						for (var count:int=0; count<this.numChildren; ++count) {
							var c:DisplayObject = this.getChildAt(count);
							if (c != target) {
								if (this.mouseX > c.x && this.mouseX < (c.x + c.width) &&
									this.mouseY > c.y && this.mouseY < (c.y + c.height)) {
										break;
									}
							}
						}
						
						var co:Coordinate = coord[target];
						var oldCount:int  = co.index;
						
						var moveEffect:Move = new Move(target);
						moveEffect.duration = EFFECT_DURATION;
							
						if (count >= this.numChildren) {
							// revert the old index and old position
							if (oldCount != this.getChildIndex(target) && oldCount >= 0 && oldCount < this.numChildren)
								this.setChildIndex(target, oldCount); 
							moveEffect.xTo = co.x;
							moveEffect.yTo = co.y;
							moveEffect.play();
							effects.push(moveEffect);
						}
						else {
							// check if a child exists at the new position and new position is different.
							var existing:UIComponent = this.getChildAt(count) as UIComponent;
							
							// first, restore the old child index of the target
							if (oldCount < this.numChildren - 1)
								this.setChildIndex(target, oldCount);
							target.validateNow();
							
							if (existing != null) {
								// if yes, then swap the two child indices and move them
								if (existing == bigChild || target == bigChild) {
//									var effect1:Parallel = new Parallel(target);
//									effect1.duration = EFFECT_DURATION;
//									var move1:Move = new Move();
//									move1.xTo = existing.x;
//									move1.yTo = existing.y;
//									var resize1:Resize = new Resize();
//									resize1.widthTo = existing.width;
//									resize1.heightTo = existing.height;
//									effect1.addChild(move1);
//									effect1.addChild(resize1);
//									effect1.play();
//									effects.push(effect1);
//									
//									var effect2:Parallel = new Parallel(existing);
//									effect2.duration = EFFECT_DURATION;
//									var move2:Move = new Move();
//									move2.xTo = co.x;
//									move2.yTo = co.y;
//									var resize2:Resize = new Resize();
//									resize2.widthTo = target.width;
//									resize2.heightTo = target.height;
//									effect2.addChild(move2);
//									effect2.addChild(resize2);
//									effect2.play();
//									effects.push(effect2);
//									
									// update bigChild after wards.
									if (existing == bigChild) {
										this.bigChild = target;
									}
									else if (target == bigChild) {
										this.bigChild = existing;
									}
								}
								else {
									if (count < oldCount) {
										this.setChildIndex(target, count);
										this.setChildIndex(existing, oldCount);
									}
									else {
										this.setChildIndex(existing, oldCount);
										this.setChildIndex(target, count);
									}
									//var pos:Position = getPosition(this.numChildren);
									//var newPos:Object = getChildPosition(count, this.numChildren, pos); 
									moveEffect.xTo = existing.x;
									moveEffect.yTo = existing.y;
									moveEffect.play();
									effects.push(moveEffect);
									
									//var oldPos:Object = getChildPosition(oldCount, this.numChildren, pos);
									var move:Move = new Move(existing);
									move.xTo = co.x;
									move.yTo = co.y;
									move.play();
									effects.push(move);
								}
								
							}
							else {
								// else move the target back to the original location
								moveEffect.xTo = co.x;
								moveEffect.yTo = co.y;
								moveEffect.play();
								effects.push(moveEffect);
								
							}
						}
						delete coord[target];
					}
					else {
						// no need to move anything else
					}
				} 
			}
		}
		
		// set draggable on rollOver.
		private function rollOverHandler(event:MouseEvent):void 
		{
			var target:UIComponent = event.currentTarget as UIComponent;
			if (target != null) {
				drags[target] = true;
			}
		}
		
		// unset draggable on rollOut.
		private function rollOutHandler(event:MouseEvent):void 
		{
			var target:UIComponent = event.currentTarget as UIComponent;
			if (target != null) {
				delete drags[target];
				if (target in coord) { // if we were dragging this, then release it
					mouseUpHandler(event);
				}
			}
		}
		
		private function childUpdateHandler(event:FlexEvent) : void 
		{
			updateBoxes();
			
			event.currentTarget.removeEventListener(event.type, childUpdateHandler);
		}
		
		// update the lastChange time, and if difference with now is less than MIN_CHANGE_TIME
		// then stop animation effects.
		private function updateLastChange():void
		{
			var now:Date = new Date();
			if (now.time - lastChange.time < MIN_CHANGE_TIME) 
				stopEffects();
			lastChange = now; 
		}
		
		// double click switches the big child in the video-box
		private function doubleClickHandler(event:MouseEvent):void
		{
			var child:DisplayObject = event.currentTarget as DisplayObject;
			if (this.contains(child)) {
				this.bigChild = (this.bigChild != child ? child : null);
			}
		}
		
	}
}

class Coordinate
{
	public var x:uint, y:uint, index:uint;
	public function Coordinate(x:uint, y:uint, index:uint) 
	{
		this.x = x;
		this.y = y;
		this.index = index;
	}
}
class Layout
{
	public var col:uint, row:uint, width:uint, height:uint;
	public function Layout(col:uint, row:uint, width:uint, height:uint)
	{
		this.col = col;
		this.row = row;
		this.width = width;
		this.height = height;
	}
}

class Position
{
	public var col:uint, row:uint, width:uint, height:uint, x0:int, y0:int;
	public var bwidth:uint, bheight:uint, bx0:uint, by0:uint, isRight:Boolean=true;
	
	public function Position(col:uint, row:uint, width:uint, height:uint, x0:int, y0:int, bwidth:uint, bheight:uint, bx0:uint, by0:uint, isRight:Boolean) 
	{
		update(col, row, width, height, x0, y0, bwidth, bheight, bx0, by0, isRight);
	}
	public function update(col:uint, row:uint, width:uint, height:uint, x0:int, y0:int, bwidth:uint, bheight:uint, bx0:uint, by0:uint, isRight:Boolean):void
	{
		this.col = col;
		this.row = row;
		this.width = width;
		this.height = height;
		this.x0 = x0;
		this.y0 = y0;
		this.bwidth = bwidth;
		this.bheight = bheight;
		this.bx0 = bx0;
		this.by0 = by0;
		this.isRight = isRight;
	}
}
