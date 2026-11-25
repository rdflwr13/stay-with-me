package zombie.characters;

import zombie.iso.IsoMovingObject;

public class IsoGameCharacter extends IsoMovingObject {
    private boolean updateModelTextures;

    public void checkUpdateModelTextures() {
    }

    public boolean isDead() {
        return false;
    }
}
