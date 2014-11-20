infinite-group-relaxation-code
==============================

This is Sage code for computation and experimentation with the
(1-dimensional) Gomory-Johnson infinite group problem, including an
electronic compendium of extreme functions.

See the survey "Light on the Infinite Group Relaxation" 
(http://www.optimization-online.org/DB_HTML/2014/10/4620.html)
for the mathematical background and a table of functions in the 
electronic compendium.

See http://www.sagemath.org/doc/tutorial/ for information on how to
use Sage.

Authors
-------

See file `<AUTHORS.rst>`_ and also `<THANKS.rst>`_

License
-------

The code is released under the GNU General Public License, version 2,
or any later version as published by the Free Software Foundation. 

How to run the code in a local copy of Sage
-------------------------------------------

1. Install Sage from http://www.sagemath.org/

2. Download the code from
   https://github.com/mkoeppe/infinite-group-relaxation-code.git

3. From the directory of the infinite-group-relaxation-code, start
   Sage.  You can either use the terminal or the worksheet.

4. At the Sage prompt, type::

    import igp; from igp import *

5. Follow the instructions and examples in `<demo.sage>`_.


How to run the code online via cloud.sagemath.com
-------------------------------------------------

1. Create a user account at https://cloud.sagemath.com

2. Log in at https://cloud.sagemath.com

3. Create a new project "Group relaxation" (or any name)

4. Open the project

5. Create a directory: 
   Paste in the weblink: https://github.com/mkoeppe/infinite-group-relaxation-code.git
   and hit enter

6. Enter that directory

7. Click "+ New", select "Sage worksheet"

8. Type::

    import igp; from igp import *

   and hit shift+enter

9. Follow the instructions and examples in `<demo.sage>`_.


To update the code to the latest version:

1. In the project "Group relaxation", open the directory "infinite-group-relaxation-code".
   
2. In the line "Terminal command...", enter::
     
    git pull 


