class Aea {
    static aea = 1;
    name = "";

    constructor(n){
        this.name = n;
        trace("Hi, im testing javascript classes, and hi " + n);
    }

    getName(){
        return this.name
    }
}