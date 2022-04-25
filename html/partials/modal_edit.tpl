<!-- Add Page Modal -->
<div class="modal fade" id="addPage" tabindex="-1" role="dialog" aria-labelledby="myModalLabel">
  <div class="modal-dialog" role="document">
    <div class="modal-content">
      <form class="" action="index.html" method="post">

        <div class="modal-header">
          <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
          <h4 class="modal-title" id="myModalLabel">Add Module</h4>
        </div>
        <div class="modal-body">

          <div class="form-group">
            <label for="pgTitle">Module Name</label>
            <input type="text" class="form-control" id="module-name" placeholder="MyGame">
          </div>
          <div class="form-group">
            <label>Module Script</label>
<div id="module-editor">
{{include: 'lua/modules/mygame/mygame.lua'}}
</div>
          </div>
          <div class="form-group">
            <label for="">
              <input type="checkbox" name="" id="module-published" value="">
              Published
            </label>
          </div>
          <div class="form-group">
            <label for="">Meta Tags:</label>
            <input type="text" class="form-control" id="module-meta-tags" placeholder="Add some tags">
            <p class="help-block">Tags to be able to search for your module.</p>
          </div>
          <div class="form-group">
            <label for="">Meta Description:</label>
            <input type="text" class="form-control" id="module-desc" placeholder="Add some description">
            <p class="help-block">A short one sentence description of your module.</p>
          </div>



        </div>
        <div class="modal-footer">
          <button type="button" class="btn btn-default" data-dismiss="modal">Close</button>
          <button type="submit" class="btn btn-primary main-bgcolors">Save changes</button>
        </div>

      </form>
    </div>
  </div>
</div>
