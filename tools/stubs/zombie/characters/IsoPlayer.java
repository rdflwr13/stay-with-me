package zombie.characters;

import zombie.iso.IsoMovingObject;

public class IsoPlayer extends IsoGameCharacter {
    public boolean CanSee(IsoMovingObject other) {
        return false;
    }

    public int getPlayerNum() {
        return 0;
    }

    public boolean isAnimal() {
        return false;
    }
}
