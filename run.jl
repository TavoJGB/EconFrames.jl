using EconFrames

sd = EconFrames.SymmetricDict((:ii,:hh) => [:hid, :imputation], (:i2,:hh) => :hid2)
sd[:ii, :hh]  # Debería funcionar ahora
sd[:hh, :ii]  # También debería funcionar