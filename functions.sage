# Make sure current directory is in path.  
# That's not true while doctesting (sage -t).
if '' not in sys.path:
    sys.path = [''] + sys.path

from igp import *


import itertools

def fractional(num):
    """
    Reduce a number modulo 1.
    """
    parent = num.parent()
    one = parent._one_element
    zero = parent._zero_element
    while num > one:
        num = num - one
    while num < zero:
        num = num + one
    return num

def delta_pi(fn,x,y):
    """
    Compute the slack in subaddivity.
    """
    return fn(fractional(x))+fn(fractional(y))-fn(fractional(x+y))

def plot_2d_complex(function):
    """
    Return a plot of the horizonal lines, vertical lines, and diagonal lines of the complex.
    """
    bkpt = function.end_points()
    x = var('x')
    p = Graphics()
    kwd = ticks_keywords(function, True)
    kwd['legend_label'] = "Complex Delta pi"
    plot_kwds_hook(kwd)
    ## We now use lambda functions instead of Sage symbolics for plotting, 
    ## as those give strange errors when combined with our RealNumberFieldElement.
    for i in range(1,len(bkpt)):
        p += plot(lambda x: bkpt[i]-x, (x, 0, bkpt[i]), color='grey', **kwd)
        kwd = {}
    for i in range(1,len(bkpt)-1):
        p += plot(lambda x: (1+bkpt[i]-x), (x, bkpt[i], 1), color='grey')
    for i in range(len(bkpt)):
        p += plot(bkpt[i], (0, 1), color='grey')
    y=var('y')
    for i in range(len(bkpt)):
        p += parametric_plot((bkpt[i],y),(y,0,1), color='grey')
    return p

## 
## A lightweight representation of closed bounded intervals, possibly empty or degenerate.
##

def interval_sum(int1, int2):
    """
    Return the sum of two intervals.
    """
    if len(int1) == 1 and len(int2) == 1:
        return [int1[0]+int2[0]]
    elif len(int1) == 2 and len(int2) == 1:
        return [int1[0]+int2[0],int1[1]+int2[0]]
    elif len(int1) == 1 and len(int2) == 2:
        return [int1[0]+int2[0],int1[0]+int2[1]]
    else:    
        return [int1[0]+int2[0],int1[1]+int2[1]]

def interval_intersection(int1, int2):
    """
    Return the intersection of two intervals.

    EXAMPLES::

        sage: interval_intersection([1], [2])
        []
        sage: interval_intersection([1,3], [2,4])
        [2, 3]
        sage: interval_intersection([1,3], [2])
        [2]
        sage: interval_intersection([2], [2,3])
        [2]
        sage: interval_intersection([1,3], [3, 4])
        [3]
        sage: interval_intersection([1,3], [4, 5])
        []
        sage: interval_intersection([], [4, 5])
        []
    """
    if len(int1) == 0 or len(int2) == 0:
        return []
    if len(int1) == 1 and len(int2) == 1:
        if int1[0] == int2[0]:
            return [int1[0]]
        else:
            return []
    elif len(int1) == 2 and len(int2) == 1:
        if int1[0] <= int2[0] <= int1[1]:
            return [int2[0]]
        else:
            return []
    elif len(int1) == 1 and len(int2) == 2:
        if int2[0] <= int1[0] <= int2[1]:
            return [int1[0]]
        else:
            return []    
    else:        
        max0 = max(int1[0],int2[0])
        min1 = min(int1[1],int2[1])
        if max0 > min1:
            return []
        elif max0 == min1:
            return [max0]
        else:
            return [max0,min1]

def interval_empty(interval):
    """
    Determine whether an interval is empty.            
    """
    if len(interval) == 0:
        return True
    else:
        return False

def interval_equal(int1, int2):
    """
    Determine whether two intervals are equal.
    (This ignores whether the intervals are represented as tuples or lists.)
    """
    return tuple(int1) == tuple(int2)

def element_of_int(x,int):
    """
    Determine whether value `x` is inside the interval `int`.

    EXAMPLES::

        sage: element_of_int(1, [])
        False
        sage: element_of_int(1, [1])
        True
        sage: element_of_int(1, [2])
        False
        sage: element_of_int(1, [0,2])
        True
        sage: element_of_int(1, [1,2])
        True
        sage: element_of_int(2, [3,4])
        False
    """
    if len(int) == 0:
        return False
    elif len(int) == 1:
        if x == int[0]:
            return True
        else:
            return False
    elif int[0] <= x <= int[1]:
        return True
    else:
        return False

def interval_to_endpoints(int):
    """
    Convert a possibly degenerate interval to a pair (a,b)
    of its endpoints, suitable for specifying pieces of a `FastPiecewise`.

    EXAMPLES::

        sage: interval_to_endpoints([1])
        (1, 1)
        sage: interval_to_endpoints([1,3])
        (1, 3)
    """
    if len(int) == 0:
        raise ValueError, "An empty interval does not have a pair representation"
    elif len(int) == 1:
        return (int[0], int[0])
    elif len(int) == 2:
        return (int[0], int[1])
    else:
        raise ValueError, "Not an interval: %s" % (int,)

def coho_interval_contained_in_coho_interval(I, J):
    I = (coho_interval_left_endpoint_with_epsilon(I), coho_interval_right_endpoint_with_epsilon(I))
    J = (coho_interval_left_endpoint_with_epsilon(J), coho_interval_right_endpoint_with_epsilon(J))
    return J[0] <= I[0] and I[1] <= J[1]

##
##
##

def projection(vertices,linear_form):
    """
    Compute the projection of vertices based on the linear form.
    vertices is a list of vertices (2-tuples)
    linear_form is a 2-element list.
    Projection on x: [1,0]
    Projection on y: [0,1]
    Projection on x + y: [1,1]
    """
    temp = []
    for i in vertices:
        temp.append(i[0]*linear_form[0]+i[1]*linear_form[1])
    if max(temp) == min(temp):
        return [min(temp)]
    else:
        return [min(temp), max(temp)]

def projections(vertices):
    """
    Compute F(I,J,K)            
    """
    return [projection(vertices, [1,0]),projection(vertices, [0,1]),projection(vertices, [1,1])]    

def verts(I1, J1, K1):
    """
    Compute the vertices based on I, J, and K.        
    """
    temp = []
    for i in I1:
        for j in J1:
            if element_of_int(i+j,K1):
                temp.append((i,j))
    for i in I1:
        for k in K1:
            if element_of_int(k-i,J1) and (i,k-i) not in temp:
                temp.append((i,k-i))             
    for j in J1:
        for k in K1:
            if element_of_int(k-j,I1) and (k-j,j) not in temp:
                temp.append((k-j,j))
    
    if len(temp) > 0:
        return temp

# Remove duplicates in a list.
# FIXME: use some builtin instead.--Matthias
def remove_duplicate(myList):
    if myList:
        myList.sort()
        last = myList[-1]
        for i in range(len(myList)-2, -1, -1):
            if last == myList[i]:
                del myList[i]
            else:
                last = myList[i]

def triples_equal(a, b):
    return interval_equal(a[0], b[0]) and interval_equal(a[1], b[1]) and interval_equal(a[2], b[2])

@cached_function
def generate_maximal_additive_faces(fn):
    if fn.is_discrete():
        return generate_maximal_additive_faces_discrete(fn)
    elif fn.is_continuous():
        return generate_maximal_additive_faces_continuous(fn)
    else:
        return generate_maximal_additive_faces_general(fn)
            
### Create a new class representing a "face" (which knows its
### vertices, minimal triple, whether it's a translation/reflection,
### etc.; whether it's solid or dense).
class Face:
    def __init__(self, triple, vertices=None, is_known_to_be_minimal=False):
        """
        EXAMPLES::

            sage: logging.disable(logging.INFO)
            sage: f = generate_maximal_additive_faces(bhk_irrational(delta=(23/250,1/125)))
        """
        if not vertices:
            vertices = verts(triple[0], triple[1], triple[2])
            if not vertices:
                raise NotImplementedError, "An empty face. This could mean need to shift triple[2] by (1,1). Not implemented."
        self.vertices = vertices
        i, j, k = projections(vertices)
        self.minimal_triple = minimal_triple = (i, j, k)
        #self._warned_about_non_minimal_triple = False
        #if is_known_to_be_minimal and not triples_equal(minimal_triple, triple) and not self._warned_about_non_minimal_triple:
        #    logging.warn("Provided triple was not minimal: %s reduces to %s" % (triple, minimal_triple))
        #    self._warned_about_non_minimal_triple = True
            # FIXME: Check why (i,j,k) != (i,j,k+1) can happen.

    def __repr__(self):
        return '<Face ' + repr(self.minimal_triple) + '>'

    def plot(self, rgbcolor=(0.0 / 255.0, 250.0 / 255.0, 154.0 / 255.0), fill_color="mediumspringgreen", *args, **kwds):
        y = var('y')
        trip = self.minimal_triple
        vert = self.vertices
        if self.is_0D():
            return point((trip[0][0], \
                          trip[1][0]), rgbcolor = rgbcolor, size = 30, **kwds)
        elif self.is_horizontal():
            return parametric_plot((y,trip[1][0]),\
                                   (y,trip[0][0], trip[0][1]), rgbcolor = rgbcolor, thickness=2, **kwds)
        elif self.is_vertical():
            return parametric_plot((trip[0][0],y),\
                                   (y,trip[1][0], trip[1][1]), rgbcolor = rgbcolor, thickness=2, **kwds)
        elif self.is_diagonal():
            return parametric_plot((lambda y: y, lambda y: trip[2][0]-y),\
                                   (y,trip[0][0],trip[0][1]), rgbcolor = rgbcolor, thickness=2, **kwds)
        elif self.is_2D():
            ## Sorting is necessary for this example:
            ## plot_2d_diagram(lift(piecewise_function_from_robert_txt_file("data/dey-richard-not-extreme.txt"))
            return polygon(convex_vert_list(vert), color=fill_color, **kwds)

    def is_directed_move(self):
        return self.is_1D() or self.is_0D()
        
    def directed_move_with_domain_and_codomain(self):
        """
        Maps a horizontal edge to a forward translation,
        a vertical edge to a backward translation, 
        a diagonal edge to a reflection.

        `domain` and `codomain` are lists of old-fashioned intervals.
        """
        # FIXME: In the discontinuous case, what is the right domain as a coho interval?
        (I, J, K) = self.minimal_triple
        if self.is_0D():
            x, y, z = I[0], J[0], K[0]
            # A 0-face corresponds to three moves:
            # \tau_y:  a translation + y with domain {x}
            # \tau_x:  a translation + x with domain {y}
            # \rho_z:  a reflection (x+y) - with domain {x, y}.
            # Because \tau_x = \tau_y \rho_z, it suffices to output
            # \tau_y and \rho_z.  We use the fact that with each additive
            # vertex, also the x_y_swapped vertex appears.
            ###
            ### FIXME: This transitivity FAILS if we use restrict=True
            ### in generate_functional_directed_moves!
            ###
            ### FIXME: This should be done relative to zero_perturbation_partial_function.
            ### Because a move is only valid if the function is fixed to zero on the move element.
            ###
            ### FIXME: To be written what this means in the continuous case.
            if x < y:
                z_mod_1 = fractional(z)
                y_adjusted = z_mod_1 - x
                return (1, y_adjusted), [[x]], [[z_mod_1]]
            else:
                return (-1, z), [[x], [y]], [[y], [x]]
        elif self.is_horizontal():
            K_mod_1 = interval_mod_1(K)
            t = K_mod_1[0] - I[0]
            return (1, t), [I], [K_mod_1]
        elif self.is_vertical():
            K_mod_1 = interval_mod_1(K)
            t = K_mod_1[0] - J[0]
            return (1, -t), [K_mod_1], [J]
        elif self.is_diagonal():
            return (-1, K[0]), [I, J], [J, I]
        else:
            raise ValueError, "Face does not correspond to a directed move: %s" % self

    def functional_directed_move(self, intervals=None):
        """If given, intervals must be sorted, disjoint"""
        directed_move, domain, codomain = self.directed_move_with_domain_and_codomain()
        fdm = FunctionalDirectedMove(domain, directed_move)
        if intervals is None: 
            return fdm
        else:
            return fdm.restricted(intervals)

    def is_0D(self):
        return len(self.vertices) == 1

    def is_1D(self):
        return len(self.vertices) == 2

    def is_2D(self):
        return len(self.vertices) > 2

    def is_horizontal(self):
        return self.is_1D() and self.vertices[0][1] == self.vertices[1][1]

    def is_vertical(self):
        return self.is_1D() and self.vertices[0][0] == self.vertices[1][0]

    def is_diagonal(self):
        return self.is_1D() and \
               self.vertices[0][0] + self.vertices[0][1] == self.vertices[1][0] + self.vertices[1][1]
    
def plot_faces(faces, **kwds):
    p = Graphics()
    for f in faces:
        if type(f) == list or type(f) == tuple: #legacy
            f = Face(f)
        p += f.plot(**kwds)
    return p

def plot_trivial_2d_diagram_with_grid(function, xgrid=None, ygrid=None): 
    """
    Return a plot of the 2d complex with vertices marked that 
    have delta_pi == 0.  Does not use any complicated code.
    Mainly used for visually double-checking the computation of 
    maximal additive faces.
    """
    if xgrid is None:
        xgrid = function.end_points()
    if ygrid is None:
        ygrid = function.end_points()
    return point([(x,y) for x in xgrid for y in ygrid \
                  if delta_pi(function, x, y) == 0],
                 color="cyan", size = 80)

def angle_cmp(a, b, center):
    # Adapted 
    # from http://stackoverflow.com/questions/6989100/sort-points-in-clockwise-order
    if a[0] - center[0] >= 0 and b[0] - center[0] < 0:
        return int(1)
    elif a[0] - center[0] < 0 and b[0] - center[0] >= 0:
        return int(-1)
    elif a[0] - center[0] == 0 and b[0] - center[0] == 0:
        return cmp(a[1], b[1])

    det = (a[0] - center[0]) * (b[1] - center[1]) - (b[0] - center[0]) * (a[1] - center[1])
    if det < 0:
        return int(1)
    elif det > 0:
        return int(-1)

    return int(0)

import operator

def convex_vert_list(vertices):
    if len(vertices) <= 3:
        return vertices
    else:
        center = reduce(operator.add, map(vector, vertices)) / len(vertices)
        return sorted(vertices, cmp = lambda a,b: angle_cmp(a, b, center))

def plot_kwds_hook(kwds):
    pass

def plot_2d_diagram(fn, show_function=True, show_projections=True, known_minimal=False, f=None):
    """
    Return a plot of the 2d complex (Delta P) of `fn` with shaded
    additive faces, i.e., faces where delta pi is 0.
    
    If `known_minimal` is False (the default), highlight
    non-subadditive or non-symmetric vertices of the 2d complex.

    If `show_function` is True (the default), plot the function at the left and top borders 
    of the diagram via `plot_function_at_borders`. 

    If `show_projections` is True (the default), plot the projections p1(F), p2(F), p3(F) of 
    all full-dimensional additive faces via `plot_projections_at_borders`.

    To show only a part of the diagram, use::

        sage: show(plot_2d_diagram(h), xmin=0.25, xmax=0.35, ymin=0.25, ymax=0.35)  # not tested

    EXAMPLES::

        sage: h = FastPiecewise([[closed_interval(0,1/4), FastLinearFunction(4, 0)],
        ...                      [open_interval(1/4, 1), FastLinearFunction(4/3, -1/3)],
        ...                      [singleton_interval(1), FastLinearFunction(0,0)]])
        sage: plot_2d_diagram(h)

        sage: h = FastPiecewise([[closed_interval(0,1/4), FastLinearFunction(4, 0)],
        ...                      [open_interval(1/4,1/2), FastLinearFunction(3, -3/4)],
        ...                      [closed_interval(1/2, 3/4), FastLinearFunction(-2, 7/4)],
        ...                      [open_interval(3/4,1), FastLinearFunction(3, -2)],
        ...                      [singleton_interval(1), FastLinearFunction(0,0)]])
        sage: plot_2d_diagram(h)

    """
    if f is None:
        f = find_f(fn, no_error_if_not_minimal_anyway=True)
    faces = generate_maximal_additive_faces(fn)
    p = plot_2d_complex(fn)
    kwds = { 'legend_label': "Additive face" }
    plot_kwds_hook(kwds)
    for face in faces:
        p += face.plot(**kwds)
        delete_one_time_plot_kwds(kwds)

    ### For non-subadditive functions, show the points where delta_pi is negative.
    if not known_minimal:
        nonsubadditive_vertices = generate_nonsubadditive_vertices(fn, reduced=False)
        kwds = { 'legend_label' : "Subadditivity violated" }
        plot_kwds_hook(kwds)
        if fn.is_continuous():
            nonsubadditive_vertices = {(x,y) for (x, y, z, xeps, yeps, zeps) in nonsubadditive_vertices}
            p += point(list(nonsubadditive_vertices),
                       color = "red", size = 50, zorder=-1, **kwds)
            p += point([ (y,x) for (x,y) in nonsubadditive_vertices ], color = "red", size = 50, zorder=-1)
        else:
            new_legend_label = False
            for (x, y, z, xeps, yeps, zeps) in nonsubadditive_vertices:
                new_legend_label = True
                p += plot_limit_cone_of_vertex(x, y, epstriple_to_cone((xeps, yeps, zeps)))
                if x != y:
                    p += plot_limit_cone_of_vertex(y, x, epstriple_to_cone((yeps, xeps, zeps)))
            if new_legend_label:
                # add legend_label
                p += point([(0,0)], color = "red", size = 50, zorder=-10, **kwds)
                p += point([(0,0)], color = "white", size = 50, zorder=-9)
        nonsymmetric_vertices = generate_nonsymmetric_vertices(fn, f)
        kwds = { 'legend_label' : "Symmetry violated" }
        plot_kwds_hook(kwds)
        if fn.is_continuous():
            nonsymmetric_vertices = {(x,y) for (x, y, xeps, yeps) in nonsymmetric_vertices}
            p += point(list(nonsymmetric_vertices),
                       color = "mediumvioletred", size = 50, zorder=5, **kwds)
            p += point([ (y,x) for (x,y) in nonsymmetric_vertices], color = "mediumvioletred", size = 50, zorder=5)
        else:
            new_legend_label = False
            for (x, y, xeps, yeps) in nonsymmetric_vertices:
                new_legend_label = True
                if (xeps, yeps) == (0, 0):
                    p += point([x, y], color="mediumvioletred", size=20, zorder=5)
                else:
                    p += disk([x, y], 0.03, (yeps* pi/2, (1 - xeps) * pi/2), color="mediumvioletred", zorder=5)
                if x != y:
                    if (xeps, yeps) == (0, 0):
                        p += point([y, x], color="mediumvioletred", size=20, zorder=5)
                    else:
                        p += disk([y, x], 0.03, (xeps* pi/2, (1 - yeps) * pi/2), color="mediumvioletred", zorder=5)
            if new_legend_label:
                # add legend_label
                p += point([(0,0)], color = "mediumvioletred", size = 50, zorder=-10, **kwds)
                p += point([(0,0)], color = "white", size = 50, zorder=-9)
    if show_projections:
        p += plot_projections_at_borders(fn)
    if show_function:
        p += plot_function_at_borders(fn)
    return p

def plot_function_at_borders(fn, color='blue', legend_label="Function pi", **kwds):
    """
    Plot the function twice, on the upper and the left border, 
    to decorate 2d diagrams.
    """
    p = Graphics()
    bkpt = fn.end_points()
    limits = fn.limits_at_end_points()
    if limits[0][0] is not None and limits[0][0] != limits[0][1]:
        p += point([(0,1), (0,0)], color=color, size = 23, zorder=-1)
    for i in range(len(bkpt) - 1):
        x1 = bkpt[i]
        y1 = limits[i][1]
        x2 = bkpt[i+1]
        y2 = limits[i+1][-1]
        y3 = limits[i+1][0]
        y4 = limits[i+1][1]
        if y1 is not None and y2 is not None:
            p += line([(x1, 0.3*y1 + 1), (x2, 0.3*y2 + 1)], color=color, zorder=-2, **kwds)
            delete_one_time_plot_kwds(kwds)
            p += line([(-0.3*y1, x1), (-0.3*y2, x2)], color=color, zorder=-2, **kwds)
        if y1 is not None and limits[i][0] != y1:
            p += point([(x1, 0.3*y1 + 1), (-0.3*y1, x1)], color=color, pointsize=23, zorder=-1)
            p += point([(x1, 0.3*y1 + 1), (-0.3*y1, x1)], color='white', pointsize=10, zorder=-1)
        if y2 is not None and y2 != y3:
            p += point([(x2, 0.3*y2 + 1), (-0.3*y2, x2)], color=color, pointsize=23, zorder=-1)
            p += point([(x2, 0.3*y2 + 1), (-0.3*y2, x2)], color='white', pointsize=10, zorder=-1)
        if y3 is not None and ((y2 != y3) or ((i < len(bkpt) - 2) and (y3 != y4))) and \
                              ((i == len(bkpt)-2) or not (y3 == y4 and y2 is None) and \
                                                     not (y2 == y3 and y4 is None)):
            p += point([(x2, 0.3*y3 + 1), (-0.3*y3, x2)], color=color, pointsize=23, zorder=-1)
    # add legend_label
    kwds = { 'legend_label': legend_label }
    plot_kwds_hook(kwds)
    if fn.is_discrete():
        p += point([(0,0)], color=color, pointsize=23, zorder=-10, **kwds)
        p += point([(0,0)], color='white', pointsize=23, zorder=-9)
    else:
        p += line([(0,0), (0,1)], color=color, zorder=-10, **kwds)
        p += line([(0,0), (0,1)], color='white', zorder=-9)
    return p

proj_plot_width = 0.02
#proj_plot_colors = ['yellow', 'cyan', 'magenta']            # very clear but ugly
#proj_plot_colors = ['darkseagreen', 'darkseagreen', 'slategray']
proj_plot_colors = ['grey', 'grey', 'grey']
proj_plot_alpha = 0.35
#proj_plot_alpha = 1

def plot_projections_at_borders(fn):
    """
    Plot the projections p1(F), p2(F), p3(F) of all full-dimensional
    additive faces F of `fn` as gray shadows: p1(F) at the top border,
    p2(F) at the left border, p3(F) at the bottom and the right
    borders.
    """
    g = Graphics()
    I_J_verts = set()
    K_verts = set()
    kwds = { 'alpha': proj_plot_alpha, 'zorder': -10 }
    if proj_plot_colors[0] == proj_plot_colors[1] == proj_plot_colors[2]:
        IJK_kwds = [ kwds for i in range(3) ]
        kwds['legend_label'] = "projections p1(F), p2(F), p3(F)"
    elif proj_plot_colors[0] == proj_plot_colors[1]:
        IJK_kwds = [ kwds, kwds, copy(kwds) ]
        kwds['legend_label'] = "projections p1(F), p2(F)"
        IJK_kwds[2]['legend_label'] = "projections p3(F)"
    else:
        IJK_kwds = [ copy(kwds) for i in range(3) ]
        for i in range(3):
            IJK_kwds[i]['legend_label'] = "projections p_%s(F)" % (i+1)
    for i in range(3):
        #IJK_kwds[i]['legend_color'] = proj_plot_colors[i] # does not work in Sage 5.11
        IJK_kwds[i]['color'] = proj_plot_colors[i]
        plot_kwds_hook(IJK_kwds[i])
    for face in generate_maximal_additive_faces(fn):
        I, J, K = face.minimal_triple
        I_J_verts.update(I) # no need for J because the x-y swapped face will also be processed
        K_verts.update(K)
        if face.is_2D():
            # plot I at top border
            g += polygon([(I[0], 1), (I[1], 1), (I[1], 1 + proj_plot_width), (I[0], 1 + proj_plot_width)], **IJK_kwds[0])
            delete_one_time_plot_kwds(IJK_kwds[0])
            # plot J at left border
            g += polygon([(0, J[0]), (0, J[1]), (-proj_plot_width, J[1]), (-proj_plot_width, J[0])], **IJK_kwds[1])
            delete_one_time_plot_kwds(IJK_kwds[1])
            # plot K at right/bottom borders
            if coho_interval_contained_in_coho_interval(K, [0,1]):
                g += polygon([(K[0], 0), (K[1], 0), (K[1] + proj_plot_width, -proj_plot_width), (K[0] + proj_plot_width, -proj_plot_width)], **IJK_kwds[2])
            elif coho_interval_contained_in_coho_interval(K, [1,2]):
                g += polygon([(1, K[0]-1), (1, K[1]-1), (1 + proj_plot_width, K[1] - 1 - proj_plot_width), (1 + proj_plot_width, K[0] - 1 - proj_plot_width)], **IJK_kwds[2])
            else:
                raise ValueError, "Bad face: %s" % face
            delete_one_time_plot_kwds(IJK_kwds[2])
    for (x, y, z, xeps, yeps, zeps) in generate_nonsubadditive_vertices(fn):
        I_J_verts.add(x)
        I_J_verts.add(y)
        K_verts.add(z)
    # plot dashed help lines corresponding to non-breakpoint projections. 
    # (plot_2d_complex already draws solid lines for the breakpoints.)
    I_J_verts.difference_update(fn.end_points())
    for x in I_J_verts:
        g += line([(x, 0), (x, 1)], linestyle=':', color='grey')
        g += line([(0, x), (1, x)], linestyle=':', color='grey')
    K_verts.difference_update(fn.end_points())
    K_verts.difference_update(1 + x for x in fn.end_points())
    for z in K_verts:
        if z <= 1:
            g += line([(0, z), (z, 0)], linestyle=':', color='grey')
        else:
            g += line([(1, z-1), (z-1, 1)], linestyle=':', color='grey')
    return g

# Assume component is sorted.
def merge_within_comp(component, one_point_overlap_suffices=False):   
    for i in range(len(component)-1):
        if component[i][1] > component[i+1][0]  \
           or (one_point_overlap_suffices and component[i][1] == component[i+1][0]):
            component[i+1] = [component[i][0],max(component[i][1],component[i+1][1])]
            component[i] = []
    component_new = []
    for int in component:
        if len(int) == 2 and max(int) <= 1:
            component_new.append(int)
    return component_new


# Assume comp1 and comp2 are sorted.    
def merge_two_comp(comp1,comp2, one_point_overlap_suffices=False):
    temp = []
    i = 0
    j = 0
    while i < len(comp1) and j < len(comp2):
        if comp1[i][0] < comp2[j][0]:
            temp.append(comp1[i])
            i = i+1
        else:
            temp.append(comp2[j])
            j = j+1
    if i == len(comp1):
        temp = temp + comp2[j:len(comp2)]
    else:
        temp = temp + comp1[i:len(comp1)]
    temp = merge_within_comp(temp, one_point_overlap_suffices=one_point_overlap_suffices)
    return temp
            

def partial_overlap(interval,component):
    """
    Return a list of the intersections of the interiors 
    of `interval` and the intervals in `component`.

    EXAMPLES::

        sage: partial_overlap([2,3], [[1,2], [3,5]])
        []
        sage: partial_overlap([2,6], [[1,3], [5,7], [7,9]])
        [[2, 3], [5, 6]]
    """
    overlap = []
    for int1 in component:
        overlapped_int = interval_intersection(interval,int1)
        if len(overlapped_int) == 2:
            overlap.append(overlapped_int)
    return overlap


def remove_empty_comp(comps):
    """
    Return a new list that includes all non-empty lists of `comps`.

    EXAMPLES::

        sage: remove_empty_comp([[[1,2]], [], [[3,4],[5,6]]])
        [[[1, 2]], [[3, 4], [5, 6]]]
    """
    temp = []
    for int in comps:
        if len(int) > 0:
            temp.append(int)
    return temp
    

def partial_edge_merge(comps, partial_overlap_intervals, ijk, ijk2, intervals, i, IJK):
    """
    Modifies the list `comps`.
    Returns whether any change occurred.
    """
    any_change = False
    for int1 in partial_overlap_intervals:
        front = int1[0] - intervals[ijk][0]
        back = intervals[ijk][1] - int1[1]
        
        # If it is not the pair I and J, then the action is a translation.
        if IJK != [0,1]:
            other = [intervals[ijk2][0]+front, intervals[ijk2][1]-back]
        # I and J implies a reflection
        else:
            other = [intervals[ijk2][0]+back, intervals[ijk2][1]-front]
        other = interval_mod_1(other)
        #print "other: ", other
            
        overlapped_component_indices = []
        i_included = False
        all_other_overlaps = []
        for k in range(len(comps)):
            other_overlap = partial_overlap(other,comps[k])
            #print "other_overlap:", other_overlap
            if other_overlap:
                #print "overlap with component", k, "is: ", other_overlap
                all_other_overlaps = merge_two_comp(all_other_overlaps, other_overlap)
                if k < i:
                    overlapped_component_indices.append(k)
                elif k > i and i_included == False:
                    overlapped_component_indices.append(i)
                    overlapped_component_indices.append(k)
                    i_included = True
                else:
                    overlapped_component_indices.append(k)
        if overlapped_component_indices == [i] :
            ## Only overlap within component i.
            # print "Self-overlap only"
            if (partial_overlap(other, comps[i]) == [other]):
                pass
            else:
                comps[overlapped_component_indices[-1]] = merge_two_comp(comps[overlapped_component_indices[-1]], [other])
                any_change = True
        elif len(overlapped_component_indices) > 0:
            ## Overlap with some other components; this will cause some merging.
            #print "Have overlapped components: ", overlapped_component_indices, "with ", i
            comps[overlapped_component_indices[-1]] = merge_two_comp(comps[overlapped_component_indices[-1]], [other])
            for j in range(len(overlapped_component_indices)-1):
                comps[overlapped_component_indices[j+1]] =  merge_two_comp(comps[overlapped_component_indices[j]],\
                     comps[overlapped_component_indices[j+1]])
                comps[overlapped_component_indices[j]] = []
            any_change = True

        # previous non-covered:
        #print "other: ", other, "all_other_overlaps: ", all_other_overlaps
        noncovered_overlap = interval_minus_union_of_intervals(other, all_other_overlaps)
        if noncovered_overlap:
            # print "Previously non-covered: ", uncovered_intervals_from_covered_intervals(comps)
            # print "Newly covered: ", noncovered_overlap
            any_change = True
            comps[i] = merge_two_comp(comps[i], noncovered_overlap)
            # print "Now non-covered: ", uncovered_intervals_from_covered_intervals(comps)
    return any_change
                  

def edge_merge(comps,intervals,IJK):
    #print "edge_merge(%s,%s,%s)" % (comps, intervals, IJK)
    any_change = False
    for i in range(len(comps)): 
        partial_overlap_intervals = partial_overlap(intervals[0],comps[i])
        # If there is overlapping...
        if len(partial_overlap_intervals) > 0:
            if partial_edge_merge(comps, partial_overlap_intervals, 0, 1, intervals, i, IJK):
                any_change = True
        # Repeat the same procedure for the other interval.
        partial_overlap_intervals = partial_overlap(intervals[1],comps[i])
        if len(partial_overlap_intervals) > 0:
            if partial_edge_merge(comps, partial_overlap_intervals, 1, 0, intervals, i, IJK):
                any_change = True
    return any_change
    
# Assume the lists of intervals are sorted.                
def find_interior_intersection(list1, list2):
    """
    Tests whether `list1` and `list2` contain a pair of intervals
    whose interiors intersect.

    Assumes both lists are sorted.
    
    EXAMPLES::

        sage: find_interior_intersection([[1, 2], [3, 4]], [[2, 3], [4, 5]])
        False
        sage: find_interior_intersection([[1, 2], [3, 5]], [[2, 4]])
        True
    """
    i=0
    j=0
    while i < len(list1) and j < len(list2):
        if len(interval_intersection(list1[i], list2[j])) == 2:
            return True
        else:
            if list1[i][0] < list2[j][0]:
                i = i + 1
            else:
                j = j + 1
    return False

def interval_mod_1(interval):
    """
    Represent the given proper interval modulo 1
    as a subinterval of [0,1].

    EXAMPLES::

        sage: interval_mod_1([1,6/5])
        [0, 1/5]
        sage: interval_mod_1([1,2])
        [0, 1]
        sage: interval_mod_1([-3/10,-1/10])
        [7/10, 9/10]
        sage: interval_mod_1([-1/5,0])
        [4/5, 1]        
    """
    interval = copy(interval)
    if len(interval) == 0:
        return interval
    elif len(interval) == 1:
        while interval[0] >= 1:
            interval[0] -= 1
        while interval[0] < 0:
            interval[0] += 1
        return interval
    elif len(interval) == 2:
        assert interval[0] < interval[1]
        while interval[0] >= 1:
            interval[0] = interval[0] - 1
            interval[1] = interval[1] - 1
        while interval[1] <= 0:
            interval[0] = interval[0] + 1
            interval[1] = interval[1] + 1
        assert not(interval[0] < 1 and interval[1] > 1) 
        return interval
    else:
        raise ValueError, "Not an interval: %s" % interval

@cached_function
def generate_directly_covered_intervals(function):
    faces = generate_maximal_additive_faces(function)

    covered_intervals = []      
    for face in faces:
        if face.is_2D():
            component = []
            for int1 in face.minimal_triple:
                component.append(interval_mod_1(int1))
            component.sort()
            component = merge_within_comp(component)
            covered_intervals.append(component)
            
    remove_duplicate(covered_intervals)
    
    #show(plot_covered_intervals(function, covered_intervals), xmax=1.5)

    for i in range(len(covered_intervals)):
        for j in range(i+1, len(covered_intervals)):
            if find_interior_intersection(covered_intervals[i], covered_intervals[j]):
                covered_intervals[j] = merge_two_comp(covered_intervals[i],covered_intervals[j])
                covered_intervals[i] = []
                    
    covered_intervals = remove_empty_comp(covered_intervals)
    return covered_intervals

@cached_function
def generate_covered_intervals(function):
    logging.info("Computing covered intervals...")
    covered_intervals = generate_directly_covered_intervals(function)
    faces = generate_maximal_additive_faces(function)

    # debugging plot:
    # show(plot_covered_intervals(function, covered_intervals), \
    #      legend_fancybox=True, \
    #      legend_title="Directly covered, merged", \
    #      legend_loc=2) # legend in upper left

    edges = [ face.minimal_triple for face in faces if face.is_1D()]

    any_change = True
    ## FIXME: Here we saturate the covered interval components
    ## with the edge relations.  There should be a smarter way
    ## to avoid this while loop.  Probably by keeping track 
    ## of a set of non-covered components (connected by edges).
    ## --Matthias
    while any_change:
        any_change = False
        for edge in edges:
            intervals = []
            # 0 stands for I; 1 stands for J; 2 stands for K
            IJK = []
            for i in range(len(edge)):
                if len(edge[i]) == 2:
                    intervals.append(edge[i])
                    IJK.append(i)
            if edge_merge(covered_intervals,intervals,IJK):
                any_change = True

    covered_intervals = remove_empty_comp(covered_intervals)
    logging.info("Computing covered intervals... done")
    return covered_intervals

def interval_minus_union_of_intervals(interval, remove_list):
    """Compute a list of intervals that represent the
    set difference of `interval` and the union of the 
    intervals in `remove_list`.

    Assumes `remove_list` is sorted (and pairwise essentially
    disjoint), and returns a sorted list.

    EXAMPLES::

        sage: interval_minus_union_of_intervals([0, 10], [[-1, 0], [2, 3], [9,11]]) 
        [[0, 2], [3, 9]]
        sage: interval_minus_union_of_intervals([0, 10], [[-1, 0], [2, 3]]) 
        [[0, 2], [3, 10]]
        sage: interval_minus_union_of_intervals([0, 10], [[-1, 0], [2, 3], [9,11], [13, 17]])
        [[0, 2], [3, 9]]
    """
    scan = scan_union_of_coho_intervals_minus_union_of_coho_intervals([[interval]], [remove_list])
    return list(proper_interval_list_from_scan(scan))

def uncovered_intervals_from_covered_intervals(covered_intervals):
    """Compute a list of uncovered intervals, given the list of components
    of covered intervals.

    EXAMPLES::

        sage: uncovered_intervals_from_covered_intervals([[[10/17, 11/17]], [[5/17, 6/17], [7/17, 8/17]]])
        [[0, 5/17], [6/17, 7/17], [8/17, 10/17], [11/17, 1]]
        sage: uncovered_intervals_from_covered_intervals([])
        [[0, 1]]
    """
    if not covered_intervals:
        return [[0,1]]
    covered = reduce(merge_two_comp, covered_intervals)
    return interval_minus_union_of_intervals([0,1], covered)

@cached_function
def generate_uncovered_intervals(function):
    """
    Compute a sorted list of uncovered intervals.
    """
    covered_intervals = generate_covered_intervals(function)
    return uncovered_intervals_from_covered_intervals(covered_intervals)

def ticks_keywords(function, y_ticks_for_breakpoints=False):
    """
    Compute `plot` keywords for displaying the ticks.
    """
    xticks = function.end_points()
    xtick_formatter = [ "$%s$" % latex(x) for x in xticks ]
    #xtick_formatter = 'latex'  # would not show rationals as fractions
    ytick_formatter = None
    if y_ticks_for_breakpoints:
        yticks = xticks
        ytick_formatter = xtick_formatter
    else:
        #yticks = 1/5
        yticks = uniq([ y for limits in function.limits_at_end_points() for y in limits if y is not None ])
        ytick_formatter = [ "$%s$" % latex(y) for y in yticks ]
    ## FIXME: Can we influence ticks placement as well so that labels don't overlap?
    ## or maybe rotate labels 90 degrees?
    return {'ticks': [xticks, yticks], \

            'gridlines': True, \
            'tick_formatter': [xtick_formatter, ytick_formatter]}

def delete_one_time_plot_kwds(kwds):
    if 'legend_label' in kwds:
        del kwds['legend_label']
    if 'ticks' in kwds:
        del kwds['ticks']
    if 'tick_formatter' in kwds:
        del kwds['tick_formatter']

def plot_covered_intervals(function, covered_intervals=None, uncovered_color='black', labels=None, **plot_kwds):
    """
    Return a plot of the covered and uncovered intervals of `function`.
    """
    if covered_intervals is None:
        covered_intervals = generate_covered_intervals(function)
        uncovered_intervals = generate_uncovered_intervals(function)
    else:
        uncovered_intervals = uncovered_intervals_from_covered_intervals(covered_intervals)
    # Plot the function with different colors.
    # Each component has a unique color.
    # The uncovered intervals is by default plotted in black.
    colors = rainbow(len(covered_intervals))
    graph = Graphics()
    kwds = copy(plot_kwds)
    kwds.update(ticks_keywords(function))
    if uncovered_intervals:
        kwds.update({'legend_label': "not covered"})
        plot_kwds_hook(kwds)
        graph += plot(function, color = uncovered_color, **kwds)
        delete_one_time_plot_kwds(kwds)
    elif not function.is_continuous(): # to plot the discontinuity markers
        graph += plot(function, color = uncovered_color, **kwds)
        delete_one_time_plot_kwds(kwds)
    for i, component in enumerate(covered_intervals):
        if labels is None:
            label = "covered component %s" % (i+1)
        else:
            label = labels[i]
        kwds.update({'legend_label': label})
        plot_kwds_hook(kwds)
        for interval in component:
            graph += plot(function.which_function((interval[0] + interval[1])/2), interval, color=colors[i], zorder=-1, **kwds)
            # zorder=-1 puts them below the discontinuity markers,
            # above the black function.
            delete_one_time_plot_kwds(kwds)
    return graph

def plot_with_colored_slopes(fn):
    """
    Return a plot of `fn`, with pieces of different slopes in different colors.
    """
    slopes_dict = dict()
    for i, f in fn.list():
        if interval_length(i) > 0:
            try: # Make sure we don't fail if passed a non-FastLinearFunction
                if f._slope not in slopes_dict:
                    slopes_dict[f._slope] = []
                slopes_dict[f._slope].append((i[0], i[1]))
            except AttributeError:
                pass
    return plot_covered_intervals(fn, slopes_dict.values(), labels=[ "Slope %s" % s for s in slopes_dict.keys() ])

def zero_perturbation_partial_function(function):
    """
    Compute the partial function for which the perturbation, modulo
    perturbations that are interpolations of values at breakpoints, is
    known to be zero.
    """
    zero_function = FastLinearFunction(0, 0)
    pieces = [ (singleton_interval(x), zero_function) for x in function.end_points() ]
    pieces += [ (interval, zero_function) for component in generate_covered_intervals(function) for interval in component ]
    return FastPiecewise(pieces)

### Minimality check.

def subadditivity_test(fn):
    """
    Check if `fn` is subadditive.
    """
    result = True
    for (x, y, z, xeps, yeps, zeps) in generate_nonsubadditive_vertices(fn, reduced=True):
        logging.info("pi(%s%s) + pi(%s%s) - pi(%s%s) < 0" % (x, print_sign(xeps), y, print_sign(yeps), z, print_sign(zeps)))
        result = False
    if result:
        logging.info("pi is subadditive.")
    else:
        logging.info("Thus pi is not subadditive.")
    return result

def symmetric_test(fn, f):
    """
    Check if `fn` is symmetric.
    """
    result = True
    if fn(f) != 1:
        logging.info('pi(f) is not equal to 1.')
        result = False
    result = True
    for (x, y, xeps, yeps) in generate_nonsymmetric_vertices(fn, f):
        logging.info("pi(%s%s) + pi(%s%s) is not equal to 1" % (x, print_sign(xeps), y, print_sign(yeps)))
        result = False
    if result:
        logging.info('pi is symmetric.')
    else:
        logging.info('Thus pi is not symmetric.')
    return result

@cached_function
def find_f(fn, no_error_if_not_minimal_anyway=False):
    """
    Find the value of `f' for the given function `fn'.
    """
    f = None
    for x in fn.end_points():
        if fn(x) > 1 or fn(x) < 0: 
            if no_error_if_not_minimal_anyway:
                logging.info('pi is not minimal because it does not stay in the range of [0, 1].')
                return None
            raise ValueError, "The given function does not stay in the range of [0, 1], so cannot determine f.  Provide parameter f to minimality_test or extremality_test."
    for x in fn.end_points():
        if fn(x) == 1:
            if not f is None:
                logging.warn("The given function has more than one breakpoint where the function takes the value 1; using f = %s.  Provide parameter f to minimality_test or extremality_test if you want a different f." % f)
                return f
            else:
                f = x
    if not f is None:
        return f
    if no_error_if_not_minimal_anyway:
        logging.info('pi is not minimal because it has no breakpoint where the function takes value 1.')
        return None
    raise ValueError, "The given function has no breakpoint where the function takes value 1, so cannot determine f.  Provide parameter f to minimality_test or extremality_test."

def minimality_test(fn, show_plots=False, f=None):
    """
    Check if `fn` is minimal with respect to the group relaxation with the given `f`. 

    If `f` is not provided, use the one found by `find_f`.

    If `show_plots` is True (default: False), show an illustrating diagram.

    This function verifies that function values stay between 0 and 1 and
    calls `subadditivity_test` and `symmetric_test`.

    EXAMPLES::

        sage: logging.disable(logging.INFO)
        sage: minimality_test(piecewise_function_from_breakpoints_and_values([0,1/5,4/5,1],[0,1/2,1,0]))
        False
        sage: minimality_test(piecewise_function_from_breakpoints_and_values([0,1/2,1], [0,2,0]))
        False
    """
    for x in fn.values_at_end_points():
        if (x < 0) or (x > 1):
            logging.info('pi is not minimal because it does not stay in the range of [0, 1].')
            return False
    if f is None:
        f = find_f(fn, no_error_if_not_minimal_anyway=True)
        if f is None:
            return False
    if fn(0) != 0:
        logging.info('pi is NOT minimal because pi(0) is not equal to 0.')
        return False
    logging.info('pi(0) = 0')
    bkpt = fn.end_points()
    if not fn.is_continuous():
        limits = fn.limits_at_end_points()
        for x in limits:
            if not ((x[-1] is None or 0 <= x[-1] <=1) and (x[1] is None or 0 <= x[1] <=1)):
                logging.info('pi is not minimal because it does not stay in the range of [0, 1].')
                return False
    if subadditivity_test(fn) and symmetric_test(fn, f):
        logging.info('Thus pi is minimal.')
        is_minimal = True
    else:
        logging.info('Thus pi is NOT minimal.')
        is_minimal = False
    if show_plots:
        logging.info("Plotting 2d diagram...")
        show_plot(plot_2d_diagram(fn, known_minimal=is_minimal, f=f),
                  show_plots, tag='2d_diagram', object=fn)
        logging.info("Plotting 2d diagram... done")
    return is_minimal

from sage.functions.piecewise import PiecewisePolynomial
from bisect import bisect_left

## FIXME: Its __name__ is "Fast..." but nobody so far has timed
## its performance against the other options. --Matthias
class FastLinearFunction :

    def __init__(self, slope, intercept):
        self._slope = slope
        self._intercept = intercept

    def __call__(self, x):
        if type(x) == float:
            # FIXME: There must be a better way.
            return float(self._slope) * x + float(self._intercept)
        else:
            return self._slope * x + self._intercept

    def __float__(self):
        return self

    def __add__(self, other):
        return FastLinearFunction(self._slope + other._slope,
                                  self._intercept + other._intercept)

    def __mul__(self, other):
        # scalar multiplication
        return FastLinearFunction(self._slope * other,
                                  self._intercept * other)


    def __neg__(self):
        return FastLinearFunction(-self._slope,
                                  -self._intercept)

    __rmul__ = __mul__

    def __eq__(self, other):
        if not isinstance(other, FastLinearFunction):
            return False
        return self._slope == other._slope and self._intercept == other._intercept

    def __ne__(self, other):
        return not (self == other)

    def __repr__(self):
        # Following the Sage convention of returning a pretty-printed
        # expression in __repr__ (rather than __str__).
        try:
            return '<FastLinearFunction ' + sage.misc.misc.repr_lincomb([('x', self._slope), (1, self._intercept)], strip_one = True) + '>'
        except TypeError:
            return '<FastLinearFunction (%s)*x + (%s)>' % (self._slope, self._intercept)

    def _sage_input_(self, sib, coerced):
        """
        Produce an expression which will reproduce this value when evaluated.
        """
        return sib.name('FastLinearFunction')(sib(self._slope), sib(self._intercept))

    ## FIXME: To be continued.

fast_linear_function = FastLinearFunction

def linear_function_through_points(p, q):
    slope = (q[1] - p[1]) / (q[0] - p[0])
    intercept = p[1] - slope * p[0]
    return FastLinearFunction(slope, intercept) 

class FastPiecewise (PiecewisePolynomial):
    """
    Returns a piecewise function from a list of (interval, function)
    pairs.

    Uses binary search to allow for faster function evaluations
    than the standard class PiecewisePolynomial.
    """
    def __init__(self, list_of_pairs, var=None, periodic_extension=True, merge=True):
        """
        EXAMPLES::

            sage: h = FastPiecewise([[(3/10, 15/40), FastLinearFunction(1, 0)], [(13/40, 14/40), FastLinearFunction(1, 0)]], merge=True)
            sage: len(h.intervals())
            1
            sage: h.intervals()[0][0], h.intervals()[0][1]
            (3/10, 3/8)
            sage: h = FastPiecewise([[(3/10, 15/40), FastLinearFunction(1, 0)], [(13/40, 14/40), FastLinearFunction(1, 0)], [(17,18), FastLinearFunction(77,78)]], merge=True)
            sage: len(h.intervals())
            2
            sage: h.intervals()[0][0], h.intervals()[0][1]
            (3/10, 3/8)
        """
        # Sort intervals according to their left endpoints; In case of equality, place single point before interval. 
        list_of_pairs = sorted(list_of_pairs, key = lambda (i, f): coho_interval_left_endpoint_with_epsilon(i))
        if merge:
            merged_list_of_pairs = []
            intervals_to_scan = []
            singleton = None
            common_f = None
            for (i, f) in list_of_pairs:
                if len(i) == 1:
                    i = singleton_interval(i[0])            # upgrade to coho interval
                if common_f == f:
                    intervals_to_scan.append(i)
                    singleton = None
                elif common_f is not None and singleton is not None and common_f(singleton) == f(singleton):
                    intervals_to_scan.append(i)
                    singleton = None
                    common_f = f
                elif i[0] == i[1] and common_f is not None and common_f(i[0]) == f(i[0]):
                    intervals_to_scan.append(i)
                else:
                    merged_intervals = union_of_coho_intervals_minus_union_of_coho_intervals([[interval] for interval in intervals_to_scan], [],
                                                                                             old_fashioned_closed_intervals=True)
                    for merged_interval in merged_intervals:
                        merged_list_of_pairs.append((merged_interval, common_f))
                    intervals_to_scan = [i]
                    if i[0] == i[1]:
                        singleton = i[0]
                    else:
                        singleton = None
                    common_f = f
            merged_intervals = union_of_coho_intervals_minus_union_of_coho_intervals([[interval] for interval in intervals_to_scan], [],
                                                                                     old_fashioned_closed_intervals=True)
            for merged_interval in merged_intervals:
                merged_list_of_pairs.append((merged_interval, common_f))
            list_of_pairs = merged_list_of_pairs
            
        PiecewisePolynomial.__init__(self, list_of_pairs, var)

        intervals = self._intervals
        functions = self._functions
        # end_points are distinct.
        end_points = []
        # ith_at_end_points records in which interval the end_point first appears as a left_end or right_end.
        ith_at_end_points = []
        # record the value at each end_point, value=None if end_point is not in the domain.
        values_at_end_points = []
        # record function values at [x, x+, x-] for each endpoint x.
        limits_at_end_points = []
        left_limit = None
        for i in range(len(intervals)):
            left_value = None
            if len(intervals[i]) <= 2 or intervals[i].left_closed:
                left_value = functions[i](intervals[i][0])
            if intervals[i][0] != intervals[i][1]:
                right_limit = functions[i](intervals[i][0])
            else:
                right_limit = None
            if (end_points == []) or (end_points[-1] != intervals[i][0]):
                end_points.append(intervals[i][0])
                ith_at_end_points.append(i)
                values_at_end_points.append(left_value)
                if limits_at_end_points != []:
                    limits_at_end_points[-1][1]= None
                limits_at_end_points.append([left_value, right_limit, None])
            else:
                if left_value is not None:
                    values_at_end_points[-1] = left_value
                    limits_at_end_points[-1][0] = left_value
                limits_at_end_points[-1][1] = right_limit
            right_value = None
            if len(intervals[i]) <= 2 or intervals[i].right_closed:
                right_value = functions[i](intervals[i][1])
            if intervals[i][0] != intervals[i][1]:
                left_limit = functions[i](intervals[i][1])
                end_points.append(intervals[i][1])
                ith_at_end_points.append(i)
                values_at_end_points.append(right_value)
                limits_at_end_points.append([right_value, None, left_limit])
            elif right_value is not None:
                values_at_end_points[-1] = right_value        
        if periodic_extension and limits_at_end_points != []:
            #if values_at_end_points[0] != values_at_end_points[-1]:
            #    logging.warn("Function is actually not periodically extendable.")
            #    periodic_extension = False
            #else:
                limits_at_end_points[0][-1] = limits_at_end_points[-1][-1]
                limits_at_end_points[-1][1] = limits_at_end_points[0][1]
        self._end_points = end_points
        self._ith_at_end_points = ith_at_end_points
        self._values_at_end_points = values_at_end_points
        self._limits_at_end_points = limits_at_end_points
        self._periodic_extension = periodic_extension

        is_continuous = True
        if len(end_points) == 1 and end_points[0] is None:
            is_continuous = False
        elif len(end_points)>= 2:
            [l0, m0, r0] = limits_at_end_points[0]
            [l1, m1, r1] = limits_at_end_points[-1]
            if m0 is None or r0 is None or  m0 != r0 or l1 is None or m1 is None or l1 != m1:
                is_continuous = False
            else:
                for i in range(1, len(end_points)-1):
                    [l, m, r] = limits_at_end_points[i]
                    if l is None or m is None or r is None or not(l == m == r):
                        is_continuous = False
                        break
        self._is_continuous = is_continuous

    # The following makes this class hashable and thus enables caching
    # of the above functions; but we must promise not to modify the
    # contents of the instance.
    def __hash__(self):
        return id(self)

    def is_continuous(self):
        """
        return if function is continuous
        """
        return self._is_continuous
        
    def is_discrete(self):
        """
        Return if the function is discrete, i.e., all pieces are singletons
        """
        return all(interval_length(interval) == 0 for interval in self.intervals())

    def end_points(self):
        """
        Returns a list of all interval endpoints for this function.
        
        EXAMPLES::
        
            sage: f1(x) = 1
            sage: f2(x) = 2
            sage: f3(x) = 1-x
            sage: f4(x) = x^2-5
            sage: f = FastPiecewise([[open_interval(0,1),f1],[singleton_interval(1),f2],[open_interval(1,2),f3],[(2,3),f4]])
            sage: f.end_points()
            [0, 1, 2, 3]
            sage: f = FastPiecewise([[open_interval(0,1),f1],[open_interval(2,3),f3]])
            sage: f.end_points()
            [0, 1, 2, 3]
        """
        return self._end_points

    def values_at_end_points(self):
        """
        Returns a list of function values at all endpoints for this function.

        EXAMPLES::

            sage: f1(x) = 1
            sage: f2(x) = 1-x
            sage: f3(x) = exp(x)
            sage: f4(x) = 4
            sage: f5(x) = sin(2*x)
            sage: f6(x) = x-3
            sage: f7(x) = 7
            sage: f = FastPiecewise([[right_open_interval(0,1),f1], \
            ...                      [right_open_interval(1,2),f2],\
            ...                      [open_interval(2,3),f3],\
            ...                      [singleton_interval(3),f4],\
            ...                      [left_open_interval(3,6),f5],\
            ...                      [open_interval(6,7),f6],\
            ...                      [(9,10),f7]])
            sage: f.values_at_end_points()
            [1, 0, None, 4, sin(12), None, 7, 7]
        """
        return self._values_at_end_points

    def limits_at_end_points(self):
        """
        Returns a list of 3-tuples [function value, right_limit, left_limit] at all endpoints for this function.

        EXAMPLES::

            sage: f1(x) = 1
            sage: f2(x) = 1-x
            sage: f3(x) = exp(x)
            sage: f4(x) = 4
            sage: f5(x) = sin(2*x)
            sage: f6(x) = x-3
            sage: f7(x) = 7
            sage: f = FastPiecewise([[right_open_interval(0,1),f1], \
            ...                      [right_open_interval(1,2),f2],\
            ...                      [open_interval(2,3),f3],\
            ...                      [singleton_interval(3),f4],\
            ...                      [left_open_interval(3,6),f5],\
            ...                      [open_interval(6,7),f6],\
            ...                      [(9,10),f7]], periodic_extension= False)
            sage: f.limits_at_end_points()
            [[1, 1, None], [0, 0, 1], [None, e^2, -1], [4, sin(6), e^3], [sin(12), 3, sin(12)], [None, None, 4], [7, 7, None], [7, None, 7]]
        """
        return self._limits_at_end_points

    def which_function(self, x0):
        """
        Returns the function piece used to evaluate self at x0.
        
        EXAMPLES::
        
            sage: f1(x) = 1
            sage: f2(x) = 1-x
            sage: f3(x) = exp(x)
            sage: f4(x) = sin(2*x)
            sage: f = FastPiecewise([[(0,1),f1],
            ...                      [(1,2),f2],
            ...                      [(2,3),f3],
            ...                      [(3,10),f4]])
            sage: f.which_function(0.5) is f1
            True
            sage: f.which_function(1) in [f1, f2]
            True
            sage: f.which_function(5/2) is f3
            True
            sage: f.which_function(3) in [f3, f4]
            True
            sage: f.which_function(-1)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point -1, outside of domain.
            sage: f.which_function(11)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point 11, outside of domain.
            sage: f = FastPiecewise([[right_open_interval(0,1),f1],
            ...                      [right_open_interval(1,2),f2],
            ...                      [right_open_interval(2,3),f3],
            ...                      [closed_interval(3,10),f4]])
            sage: f.which_function(0.5) is f1
            True
            sage: f.which_function(1) is f2
            True
            sage: f.which_function(5/2) is f3
            True
            sage: f.which_function(3) is f4
            True
            sage: f = FastPiecewise([[open_interval(0,1),f1],
            ...                      [right_open_interval(2,3),f3]])
            sage: f.which_function(0)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point 0, outside of domain.
            sage: f.which_function(0.5) is f1
            True
            sage: f.which_function(1)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point 1, outside of domain.
            sage: f.which_function(3/2)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point 3/2, outside of domain.
            sage: f.which_function(2) is f3
            True
            sage: f.which_function(5/2) is f3
            True
            sage: f.which_function(3)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point 3, outside of domain.
        """
        endpts = self.end_points()
        ith = self._ith_at_end_points
        i = bisect_left(endpts, x0)
        if i >= len(endpts):
            raise ValueError,"Value not defined at point %s, outside of domain." % x0
        if x0 == endpts[i]:
            if self._values_at_end_points[i] is not None:
                if self.functions()[ith[i]](x0) == self._values_at_end_points[i]:
                    return self.functions()[ith[i]]
                else:
                    return self.functions()[ith[i]+1]
            else:
                raise ValueError,"Value not defined at point %s, outside of domain." % x0
        if i == 0:
            raise ValueError,"Value not defined at point %s, outside of domain." % x0
        if is_pt_in_interval(self._intervals[ith[i]],x0):
            return self.functions()[ith[i]]
        raise ValueError,"Value not defined at point %s, outside of domain." % x0

    @cached_method
    def __call__(self,x0):
        """
        Evaluates self at x0. 
        
        EXAMPLES::
        
            sage: f1(x) = 1
            sage: f2(x) = 1-x
            sage: f3(x) = exp(x)
            sage: f4(x) = sin(2*x)
            sage: f = FastPiecewise([[(0,1),f1],
            ...                      [(1,2),f2],
            ...                      [(2,3),f3],
            ...                      [(3,10),f4]])
            sage: f(0.5)
            1
            sage: f(1)
            0
            sage: f(5/2)
            e^(5/2)
            sage: f(3)
            sin(6)
            sage: f(-1)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point -1, outside of domain.
            sage: f(11)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point 11, outside of domain.
            sage: f = FastPiecewise([[right_open_interval(0,1),f1],
            ...                      [right_open_interval(1,2),f2],
            ...                      [right_open_interval(2,3),f3],
            ...                      [closed_interval(3,10),f4]])
            sage: f(0.5)
            1
            sage: f(1)
            0
            sage: f(5/2)
            e^(5/2)
            sage: f(3)
            sin(6)
            sage: f = FastPiecewise([[open_interval(0,1),f1],
            ...                      [right_open_interval(2,3),f3]])
            sage: f(0)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point 0, outside of domain.
            sage: f(0.5)
            1
            sage: f(1)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point 1, outside of domain.
            sage: f(3/2)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point 3/2, outside of domain.
            sage: f(2)
            e^2
            sage: f(5/2)
            e^(5/2)
            sage: f(3)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point 3, outside of domain.
        """
        # Remember that intervals are sorted according to their left endpoints; singleton has priority.
        endpts = self.end_points()
        ith = self._ith_at_end_points
        i = bisect_left(endpts, x0)
        if i >= len(endpts):
            raise ValueError,"Value not defined at point %s, outside of domain." % x0
        if x0 == endpts[i]:
            if self._values_at_end_points[i] is not None:
                return self._values_at_end_points[i]
            else:
                raise ValueError,"Value not defined at point %s, outside of domain." % x0
        if i == 0:
            raise ValueError,"Value not defined at point %s, outside of domain." % x0
        if is_pt_in_interval(self._intervals[ith[i]],x0):
            return self.functions()[ith[i]](x0)
        raise ValueError,"Value not defined at point %s, outside of domain." % x0

    def limits(self, x0):
        """
        return [function value at x0, function value at x0+, function value at x0-].

        EXAMPLES::

            sage: f1(x) = 1
            sage: f2(x) = 1-x
            sage: f3(x) = exp(x)
            sage: f4(x) = 4
            sage: f5(x) = sin(2*x)
            sage: f6(x) = x-3
            sage: f7(x) = 7
            sage: f = FastPiecewise([[right_open_interval(0,1),f1], \
            ...                      [right_open_interval(1,2),f2],\
            ...                      [open_interval(2,3),f3],\
            ...                      [singleton_interval(3),f4],\
            ...                      [left_open_interval(3,6),f5],\
            ...                      [open_interval(6,7),f6],\
            ...                      [(9,10),f7]], periodic_extension=False)
            sage: f.limits(1/2)
            [1, 1, 1]
            sage: f.limits(1)
            [0, 0, 1]
            sage: f.limits(2)
            [None, e^2, -1]
            sage: f.limits(3)
            [4, sin(6), e^3]
            sage: f.limits(6)
            [sin(12), 3, sin(12)]
            sage: f.limits(7)
            [None, None, 4]
            sage: f.limits(8)
            [None, None, None]
            sage: f.limits(9)
            [7, 7, None]
        """
        endpts = self.end_points()
        ith = self._ith_at_end_points
        i = bisect_left(endpts, x0)
        if i >= len(endpts):
            return [None, None, None]
        if x0 == endpts[i]:
            return self.limits_at_end_points()[i]
        if i == 0:
            return [None, None, None]
        if is_pt_in_interval(self._intervals[ith[i]],x0):
            result = self.functions()[ith[i]](x0)
            return [result, result, result]
        return [None, None, None]

    def limit(self, x0, epsilon):
        """
        return limit (from right if epsilon > 0, from left if epsilon < 0) value at x0;
        if epsilon == 0, return value at x0.

        EXAMPLES::

            sage: f1(x) = 1
            sage: f2(x) = 1-x
            sage: f3(x) = exp(x)
            sage: f4(x) = 4
            sage: f5(x) = sin(2*x)
            sage: f6(x) = x-3
            sage: f7(x) = 7
            sage: f = FastPiecewise([[right_open_interval(0,1),f1], \
            ...                      [right_open_interval(1,2),f2],\
            ...                      [open_interval(2,3),f3],\
            ...                      [singleton_interval(3),f4],\
            ...                      [left_open_interval(3,6),f5],\
            ...                      [open_interval(6,7),f6],\
            ...                      [(9,10),f7]], periodic_extension=False)
            sage: f.limit(1,0)
            0
            sage: f.limit(1,1)
            0
            sage: f.limit(2,-1)
            -1
            sage: f.limit(2,0)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point 2, outside of domain.
            sage: f.limit(7,1)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point 7+, outside of domain.
            sage: f.limit(8,-1)
            Traceback (most recent call last):
            ...
            ValueError: Value not defined at point 8-, outside of domain.
        """
        result =self.limits(x0)[epsilon]
        if result is None:
            raise ValueError,"Value not defined at point %s%s, outside of domain." % (x0, print_sign(epsilon))
        return result

    def which_function_on_interval(self, interval):
        x = (interval[0] + interval[1]) / 2
        # FIXME: This should check that the given `interval` is contained in the defining interval!
        # This could be implemented by refactoring which_function using new function which_function_index.
        return self.which_function(x)

    def __add__(self,other):
        """
        In contrast to PiecewisePolynomial.__add__, this does not do zero extension of domains.
        Rather, the result is only defined on the intersection of the domains.

        EXAMPLES::

            sage: f = FastPiecewise([[singleton_interval(1), FastLinearFunction(0,17)]])
            sage: g = FastPiecewise([[[0,2], FastLinearFunction(0,2)]])
            sage: (f+g).list()
            [[<Int{1}>, <FastLinearFunction 19>]]
            sage: h = FastPiecewise([[open_interval(1,3), FastLinearFunction(0,3)]])
            sage: (g+h).list()
            [[<Int(1, 2]>, <FastLinearFunction 5>]]
            sage: j = FastPiecewise([[open_interval(0,1), FastLinearFunction(0,1)], [[1, 3], FastLinearFunction(0, 5)]])
            sage: (g+j).list()
            [[<Int(0, 1)>, <FastLinearFunction 3>], [(1, 2), <FastLinearFunction 7>]]
        """
        intervals = intersection_of_coho_intervals([self.intervals(), other.intervals()])
        return FastPiecewise([ (interval, self.which_function_on_interval(interval) + other.which_function_on_interval(interval))
                               for interval in intervals ], merge=True)

    def __neg__(self):
        return FastPiecewise([[interval, -f] for interval,f in self.list()], merge=True)
        
    def __mul__(self,other):
        """In contrast to PiecewisePolynomial.__mul__, this does not do zero extension of domains.
        Rather, the result is only defined on the intersection of the domains."""
        if not isinstance(other, FastPiecewise):
            # assume scalar multiplication
            return FastPiecewise([[interval, other*f] for interval,f in self.list()])
        else:
            intervals = intersection_of_coho_intervals([self.intervals(), other.intervals()])
            return FastPiecewise([ (interval, self.which_function_on_interval(interval) * other.which_function_on_interval(interval))
                                   for interval in intervals ], merge=True)

    __rmul__ = __mul__

    def __div__(self, other):
        return self * (1 / other)

    def __sub__(self, other):
        return self + (-other)

    ## Following just fixes a bug in the plot method in piecewise.py
    ## (see doctests below).  Also adds plotting of single points.
    def plot(self, *args, **kwds):
        """
        Returns the plot of self.
        
        Keyword arguments are passed onto the plot command for each piece
        of the function. E.g., the plot_points keyword affects each
        segment of the plot.
        
        EXAMPLES::
        
            sage: f1(x) = 1
            sage: f2(x) = 1-x
            sage: f3(x) = exp(x)
            sage: f4(x) = sin(2*x)
            sage: f = FastPiecewise([[(0,1),f1],[(1,2),f2],[(2,3),f3],[(3,10),f4]])
            sage: P = f.plot(rgbcolor=(0.7,0.1,0), plot_points=40)
            sage: P
        
        Remember: to view this, type show(P) or P.save("path/myplot.png")
        and then open it in a graphics viewer such as GIMP.

        TESTS:

        We should not add each piece to the legend individually, since
        this creates duplicates (:trac:`12651`). This tests that only
        one of the graphics objects in the plot has a non-``None``
        ``legend_label``::

            sage: f1(x) = sin(x)
            sage: f2(x) = cos(x)
            sage: f = FastPiecewise([[(-1,0), f1],[(0,1), f2]])
            sage: p = f.plot(legend_label='$f(x)$')
            sage: lines = [
            ...     line
            ...     for line in p._objects
            ...     if line.options()['legend_label'] is not None ]
            sage: len(lines)
            1

        The implementation of the plot method in Sage 5.11 piecewise.py
        is incompatible with the use of the xmin and xmax arguments.  Test that
        this has been fixed::

            sage: q = f.plot(xmin=0, xmax=3)
            sage: q = plot(f, xmin=0, xmax=3)
            sage: q = plot(f, 0, 3)
            sage: q = plot(f, 0, 3, color='red')
        
        The implementation should crop according to the given xmin, xmax::

            sage: q = plot(f, 1/2, 3)
            sage: q = plot(f, 1, 2)
            sage: q = plot(f, 2, 3)
        
        Also the following plot syntax should be accepted::

            sage: q = plot(f, [2, 3])

        """
        from sage.plot.all import plot, Graphics

        g = Graphics()
        if not 'rgbcolor' in kwds:
            color = 'blue'
        else:
            color = kwds['rgbcolor']
        ### Code duplication with xmin/xmax code in plot.py.
        n = len(args)
        xmin = None
        xmax = None
        if n == 0:
            # if there are no extra args, try to get xmin,xmax from
            # keyword arguments
            xmin = kwds.pop('xmin', None)
            xmax = kwds.pop('xmax', None)
        elif n == 1:
            # if there is one extra arg, then it had better be a tuple
            xmin, xmax = args[0]
            args = []
            ## The case where the tuple is longer than 2 elements is for the 
            ## case of symbolic expressions; it does not apply here.
            ## FIXME: We should probably signal an error.
        elif n == 2:
            # if there are two extra args, they should be xmin and xmax
            xmin = args[0]
            xmax = args[1]
            args = []
        ## The case with three extra args is for the case of symbolic
        ## expressions; it does not apply here.  FIXME: We should
        ## probably signal an error.
        point_kwds = dict()
        if 'alpha' in kwds:
            point_kwds['alpha'] = kwds['alpha']
        if 'legend_label' in kwds and self.is_discrete():
            point_kwds['legend_label'] = kwds['legend_label']
        # record last right endpoint, then compare with next left endpoint to decide whether it needs to be plotted.
        last_end_point = []
        last_closed = True
        for (i, f) in self.list():
            a = i[0]
            b = i[1]
            left_closed = True
            right_closed = True
            if len(i) > 2: # coho interval
                left_closed = i.left_closed
                right_closed = i.right_closed
            # using the above data.
            if (xmin is not None) and (a < xmin):
                a = xmin
                left_closed = True
            if (xmax is not None) and (b > xmax):
                b = xmax
                right_closed = True
            # Handle open/half-open intervals here
            if (a < b) or (a == b) and (left_closed) and (right_closed):
                if not (last_closed or last_end_point == [a, f(a)] and left_closed):
                    # plot last open right endpoint
                    g += point(last_end_point, color=color, pointsize=23, **point_kwds)
                    delete_one_time_plot_kwds(point_kwds)
                    g += point(last_end_point, rgbcolor='white', pointsize=10, **point_kwds)
                if last_closed and last_end_point != [] and last_end_point != [a, f(a)] and not left_closed:
                    # plot last closed right endpoint
                    g += point(last_end_point, color=color, pointsize=23, **point_kwds)
                    delete_one_time_plot_kwds(point_kwds)
                if not (left_closed or last_end_point == [a, f(a)] and last_closed):
                    # plot current open left endpoint
                    g += point([a, f(a)], color=color, pointsize=23, **point_kwds)
                    delete_one_time_plot_kwds(point_kwds)
                    g += point([a, f(a)], rgbcolor='white', pointsize=10, **point_kwds)
                if left_closed and last_end_point != [] and last_end_point != [a, f(a)] and not last_closed:
                    # plot current closed left endpoint
                    g += point([a, f(a)], color=color, pointsize=23, **point_kwds)
                    delete_one_time_plot_kwds(point_kwds)
                last_closed = right_closed
                last_end_point = [b, f(b)]
            if a < b:
                # We do not plot anything if a==b because
                # otherwise plot complains that
                # "start point and endpoint must be different"
                g += plot(f, *args, xmin=a, xmax=b, zorder=-1, **kwds)
                # If it's the first piece, pass all arguments. Otherwise,
                # filter out 'legend_label' so that we don't add each
                # piece to the legend separately (trac #12651).
                delete_one_time_plot_kwds(kwds)
                #delete_one_time_plot_kwds(point_kwds)
            elif (a == b) and (left_closed) and (right_closed):
                g += point([a, f(a)], color=color, pointsize=23, **point_kwds)
                delete_one_time_plot_kwds(point_kwds)
        # plot open rightmost endpoint. minimal functions don't need this.
        if not last_closed:
            g += point(last_end_point, color=color,pointsize=23, **point_kwds)
            delete_one_time_plot_kwds(point_kwds)
            g += point(last_end_point, rgbcolor='white', pointsize=10, **point_kwds)
        return g

    def is_continuous_defined(self, xmin=0, xmax=1):
        """
        return True if self is defined on [xmin,xmax] and is continuous on [xmin,xmax]
        """
        bkpt = self._end_points
        if xmin < bkpt[0] or xmax > bkpt[-1]:
            return False
        if xmin == xmax:
            return (self(xmin) is not None)
        limits = self._limits_at_end_points
        i = 0
        while bkpt[i] < xmin:
            i += 1
        if bkpt[i] == xmin:
            if limits[i][0] is None or limits[i][1] is None or limits[i][0] != limits[i][1]:
                return False 
            i += 1
        while bkpt[i] < xmax:
            if limits[i][-1] is None or limits[i][0] is None or limits[i][1] is None or \
                                        not (limits[i][-1] == limits[i][0] == limits[i][1]):
                return False
            i += 1
        if bkpt[i] == xmax:
            if limits[i][0] is None or limits[i][-1] is None or limits[i][0] != limits[i][-1]:
                return False
        return True

    def __repr__(self):
        rep = "<FastPiecewise with %s parts, " % len(self._functions)
        for interval, function in itertools.izip(self._intervals, self._functions):
            rep += "\n " + repr(interval) + "\t" + repr(function) \
                   + "\t values: " + repr([function(interval[0]), function(interval[1])])
        rep += ">"
        return rep

    def _sage_input_(self, sib, coerced):
        """
        Produce an expression which will reproduce this value when evaluated.
        """
        # FIXME: Add keyword arguments
        # FIXME: "sage_input(..., verify=True)" does not work yet
        # because of module trouble?
        return sib.name('FastPiecewise')(sib(self.list()))


def singleton_piece(x, y):
    return (singleton_interval(x), FastLinearFunction(0, y))

def open_piece(p, q):
    return (open_interval(p[0], q[0]), linear_function_through_points(p, q))

def closed_piece(p, q):
    return (closed_interval(p[0], q[0]), linear_function_through_points(p, q))

def left_open_piece(p, q):
    return (left_open_interval(p[0], q[0]), linear_function_through_points(p, q))

def right_open_piece(p, q):
    return (right_open_interval(p[0], q[0]), linear_function_through_points(p, q))

        
def print_sign(epsilon):
    if epsilon > 0:
        return "+"
    elif epsilon < 0:
        return "-"
    else:
        return ""

def is_pt_in_interval(i, x0):
    """
    retrun whether the point x0 is contained in the (ordinary or coho) interval i.
    """
    if len(i) == 2:
        return bool(i[0] <= x0 <= i[1])
    else:  
        if i.left_closed and i.right_closed:
            return bool(i.a <= x0 <= i.b)
        if i.left_closed and not i.right_closed:
            return bool(i.a <= x0 < i.b)
        if not i.left_closed and i.right_closed:
            return bool(i.a < x0 <= i.b)
        if not i.left_closed and not i.right_closed:
            return bool(i.a < x0 < i.b)

default_precision = 53

default_field = RealNumberField   # can set to SR instead to keep fully symbolic

def can_coerce_to_QQ(x):
    try:
        QQ(x)
        return True
    except ValueError:
        pass
    except TypeError:
        pass
    return False

def is_all_QQ(values):
    is_rational = False
    try:
        values = [ QQ(x) for x in values ]
        is_rational = True
    except ValueError:
        pass
    except TypeError:
        pass
    return is_rational, values

def nice_field_values(symb_values, field=None):
    """
    Coerce the real numbers in the list `symb_values` into a convenient common field
    and return a list, parallel to `symb_values`, of the coerced values.

    If all given numbers are rational, the field will be the rational
    field (`QQ`).  

    Otherwise, if the numbers are algebraic, the field
    will be a suitable algebraic field extension of the rational
    numbers, embedded into the real numbers, in the form of a
    `RealNumberField`.  

    Otherwise, the given numbers are returned as is.
    """
    ### Add tests!
    if isinstance(field, SymbolicRealNumberField):
        syms = []
        vals = []
        for element in symb_values:
            if isinstance(element,SymbolicRNFElement):
                syms.append(element.sym())
                vals.append(element.val())
            else:
                syms.append(element)  # changed to not do SR. -mkoeppe
                vals.append(element)
        vals = nice_field_values(vals) #, field=RealNumberField)
        field_values = [SymbolicRNFElement(vals[i],syms[i], parent=field) for i in range(len(symb_values))]
        return field_values

    if field is None:
        field = default_field
    is_rational, field_values = is_all_QQ(symb_values)
    if is_rational:
        logging.info("Rational case.")
        return field_values
    is_realnumberfield, field_values = is_all_the_same_real_number_field(symb_values)
    if is_realnumberfield:
        return field_values
    if field == RealNumberField and not is_rational and not is_realnumberfield:
        # Try to make it a RealNumberField:
        try:
            all_values = [ AA(x) for x in symb_values ]
            #global number_field, number_field_values, morphism, exact_generator, embedded_field, embedding_field, hom, embedded_field_values
            number_field, number_field_values, morphism = number_field_elements_from_algebraics(all_values)
            # Now upgrade to a RealNumberField
            exact_generator = morphism(number_field.gen(0))
            # Use our own RealNumberField.
            symbolic_generator = SR(exact_generator)  # does not quite work --> we won't recover our nice symbolic expressions that way
            if number_field.polynomial().degree() == 2:
                embedding_field = RR  # using a RIF leads to strange infinite recursion
            else:
                embedding_field = RealIntervalField(default_precision)
            embedded_generator = embedding_field(exact_generator)
            embedded_field = RealNumberField(number_field.polynomial(), number_field.variable_name(), \
                                             embedding=embedded_generator, exact_embedding=symbolic_generator)
            hom = number_field.hom([embedded_field.gen(0)])
            embedded_field_values = map(hom, number_field_values)
            # Store symbolic expression
            for emb, symb in itertools.izip(embedded_field_values, symb_values):
                if symb in SR and type(emb) == RealNumberFieldElement:
                    emb._symbolic = symb
            # Transform given data
            field_values = embedded_field_values
            logging.info("Coerced into real number field: %s" % embedded_field)
        except ValueError:
            logging.info("Coercion to a real number field failed, keeping it symbolic")
            pass
        except TypeError:
            logging.info("Coercion to a real number field failed, keeping it symbolic")
            pass
    return field_values

#@logger
def piecewise_function_from_breakpoints_slopes_and_values(bkpt, slopes, values, field=None):
    """
    Create a continuous piecewise function from `bkpt`, `slopes`, and `values`.

    `bkpt` and `values` are two parallel lists; it is assumed that `bkpt` is 
    sorted in increasing order. 

    `slopes` is one element shorter and represents the slopes of the interpolation.

    The function is overdetermined by these data.  The consistency of the data is 
    currently not checked.

    The data are coerced into a common convenient field via `nice_field_values`.
    """
    if field is None:
        field = default_field
    # global symb_values
    symb_values = bkpt + slopes + values
    field_values = nice_field_values(symb_values, field)
    bkpt, slopes, values = field_values[0:len(bkpt)], field_values[len(bkpt):len(bkpt)+len(slopes)], field_values[-len(values):]
    intercepts = [ values[i] - slopes[i]*bkpt[i] for i in range(len(slopes)) ]
    # Make numbers nice
    ## slopes = [ canonicalize_number(slope) for slope in slopes ]
    ## intercepts = [ canonicalize_number(intercept) for intercept in intercepts ]
    #print slopes
    return FastPiecewise([ [(bkpt[i],bkpt[i+1]), 
                            fast_linear_function(slopes[i], intercepts[i])] for i in range(len(bkpt)-1) ])

def piecewise_function_from_breakpoints_and_values(bkpt, values, field=None):
    """
    Create a continuous piecewise function from `bkpt` and `values`.

    `bkpt` and `values` are two parallel lists; assuming `bpkt` is sorted (increasing).

    The data are coerced into a common convenient field via `nice_field_values`.
    """
    if len(bkpt)!=len(values):
        raise ValueError, "Need to have the same number of breakpoints and values."
    slopes = [ (values[i+1]-values[i])/(bkpt[i+1]-bkpt[i]) for i in range(len(bkpt)-1) ]
    return piecewise_function_from_breakpoints_slopes_and_values(bkpt, slopes, values, field)

def piecewise_function_from_breakpoints_and_slopes(bkpt, slopes, field=None):
    """
    Create a continuous piecewise function from `bkpt` and `slopes`.

    `bkpt` and `slopes` are two parallel lists (except that `bkpt` is
    one element longer); assuming `bpkt` is sorted (increasing).  The
    function always has value 0 on bkpt[0].  

    The data are coerced into a common convenient field via `nice_field_values`.
    """
    if len(bkpt)!=len(slopes)+1:
        raise ValueError, "Need to have one breakpoint more than slopes."
    values = [0]
    for i in range(1,len(bkpt)-1):
        values.append(values[i-1] + slopes[i - 1] * (bkpt[i] - bkpt[i-1]))
    return piecewise_function_from_breakpoints_slopes_and_values(bkpt, slopes, values, field)

def piecewise_function_from_interval_lengths_and_slopes(interval_lengths, slopes, field=None):
    """
    Create a continuous piecewise function from `interval_lengths` and `slopes`.

    The function always has value 0 on 0. `interval_lengths` and
    `slopes` are two parallel lists that define the function values to
    the right of 0.

    The data are coerced into a common convenient field via `nice_field_values`.

    """
    if len(interval_lengths)!=len(slopes):
        raise ValueError, "Number of given interval_lengths and slopes needs to be equal."
    bkpt = []
    bkpt.append(0)
    for i in range(len(interval_lengths)):
        if interval_lengths[i] < 0:
            raise ValueError, "Interval lengths must be non-negative."
        bkpt.append(bkpt[i]+interval_lengths[i])
    return piecewise_function_from_breakpoints_and_slopes(bkpt, slopes, field)

def discrete_function_from_points_and_values(points, values, field=None):
    """
    Create a function defined on a finite list of `points`. 

    `points` and `values` are two parallel lists.

    The data are coerced into a common convenient field via `nice_field_values`.
    """
    if field is None:
        field = default_field
    # global symb_values
    symb_values = points + values
    field_values = nice_field_values(symb_values, field)
    points, values = field_values[0:len(points)], field_values[-len(values):]
    pieces = [ (singleton_interval(point), FastLinearFunction(0, value))
               for point, value in itertools.izip(points, values) ]
    return FastPiecewise(pieces)

def limiting_slopes(fn):
    """
    Compute the limiting slopes on the right and the left side of the
    origin.
    
    The function `fn` is assumed minimal.

    EXAMPLES::

        sage: logging.disable(logging.WARN) # Suppress output in automatic tests.
        sage: limiting_slopes(gmic(f=4/5))
        (5/4, -5)
        sage: limiting_slopes(gmic_disjoint_with_singletons(f=4/5))
        (5/4, -5)
        sage: limiting_slopes(minimal_no_covered_interval())
        (+Infinity, -Infinity)
        sage: limiting_slopes(drlm_2_slope_limit_1_1())
        (2, -Infinity)
        sage: limiting_slopes(restrict_to_finite_group(gmic(f=4/5)))
        (5/4, -5)
    """
    breakpoints = fn.end_points()
    limits = fn.limits_at_end_points()
    assert breakpoints[0] == 0
    if limits[0][0] > 0 or limits[0][1] > 0:
        limit_plus = +Infinity
    elif limits[1][-1] is not None:
        limit_plus = limits[1][-1] / breakpoints[1]
    else:
        limit_plus = limits[1][0] / breakpoints[1]
    assert breakpoints[-1] == 1
    if limits[-1][0] > 0 or limits[-1][-1] > 0:
        limit_minus = -Infinity
    elif limits[-2][+1] is not None:
        limit_minus = -limits[-2][+1] / (1 - breakpoints[-2])
    else:
        limit_minus = -limits[-2][0] / (1 - breakpoints[-2])
    return limit_plus, limit_minus

maximal_asymmetric_peaks_around_orbit = 'maximal_asymmetric_peaks_around_orbit'
maximal_symmetric_peaks_around_orbit = 'maximal_symmetric_peaks_around_orbit'
narrow_symmetric_peaks_around_orbit = 'narrow_symmetric_peaks_around_orbit'
recentered_symmetric_peaks = 'recentered_symmetric_peaks'
recentered_peaks_with_slopes_proportional_to_limiting_slopes_for_positive_epsilon = 'recentered_peaks_with_slopes_proportional_to_limiting_slopes_for_positive_epsilon'
recentered_peaks_with_slopes_proportional_to_limiting_slopes_for_negative_epsilon = 'recentered_peaks_with_slopes_proportional_to_limiting_slopes_for_negative_epsilon'

default_perturbation_style = maximal_asymmetric_peaks_around_orbit

def approx_discts_function(perturbation_list, stability_interval, field=default_field, \
                           perturbation_style=default_perturbation_style, function=None):
    """
    Construct a function that has peaks of +/- 1 around the points of the orbit.
    perturbation_list actually is a dictionary.
    """
    perturb_points = sorted(perturbation_list.keys())
    fn_values = [0]
    fn_bkpt = [0]
    # This width is chosen so that the peaks are disjoint, and
    # so a nice continuous piecewise linear function is constructed.
    if perturbation_style==maximal_asymmetric_peaks_around_orbit or perturbation_style==maximal_symmetric_peaks_around_orbit or narrow_symmetric_peaks_around_orbit:
        width = min(abs(stability_interval.a),stability_interval.b)
        assert width > 0, "Width of stability interval should be positive"
        assert stability_interval.a < 0 < stability_interval.b, \
            "Stability interval should contain 0 in it s interior"
    for pt in perturb_points:
        sign = perturbation_list[pt][0] # the "walk_sign" (character) at the point
        if perturbation_style==maximal_asymmetric_peaks_around_orbit:
            if sign == 1:
                left = pt + stability_interval.a
                right = pt + stability_interval.b
            else:
                left = pt - stability_interval.b
                right = pt - stability_interval.a
        elif perturbation_style==maximal_symmetric_peaks_around_orbit:
            left = pt - width
            right = pt + width
        elif perturbation_style==narrow_symmetric_peaks_around_orbit:
            left = pt - width/1000
            right = pt + width/1000
        elif perturbation_style==recentered_symmetric_peaks:
            if sign == 1:
                left = pt + stability_interval.a
                right = pt + stability_interval.b
            else:
                left = pt - stability_interval.b
                right = pt - stability_interval.a
            pt = (left + right) /2
        elif perturbation_style==recentered_peaks_with_slopes_proportional_to_limiting_slopes_for_positive_epsilon:
            if function is None:
                raise ValueError, "This perturbation_style needs to know function"
            slope_plus, slope_minus = limiting_slopes(function)
            current_slope = function.which_function(pt + (stability_interval.b + stability_interval.a)/2)._slope 
            x = (stability_interval.b - stability_interval.a) * (slope_minus - current_slope)/(slope_minus-slope_plus)
            if sign == 1:
                left = pt + stability_interval.a
                right = pt + stability_interval.b
                pt = left + x
            else:
                left = pt - stability_interval.b
                right = pt - stability_interval.a
                pt = right - x
        elif perturbation_style==recentered_peaks_with_slopes_proportional_to_limiting_slopes_for_negative_epsilon:
            if function is None:
                raise ValueError, "This perturbation_style needs to know function"
            slope_plus, slope_minus = limiting_slopes(function)
            current_slope = function.which_function(pt + (stability_interval.b + stability_interval.a)/2)._slope 
            x = (stability_interval.b - stability_interval.a) * (slope_plus - current_slope)/(slope_plus-slope_minus)
            if sign == 1:
                left = pt + stability_interval.a
                right = pt + stability_interval.b
                pt = left + x
            else:
                left = pt - stability_interval.b
                right = pt - stability_interval.a
                pt = right - x
        else:
            raise ValueError, "Unknown perturbation_style: %s" % perturbation_style
        assert (left >= fn_bkpt[len(fn_bkpt)-1])
        if (left > fn_bkpt[len(fn_bkpt)-1]):
            fn_bkpt.append(left)
            fn_values.append(0)
        fn_bkpt.append(pt)
        fn_values.append(sign)
        fn_bkpt.append(right)
        fn_values.append(0)
    assert (1 >= fn_bkpt[len(fn_bkpt)-1])
    if (1 > fn_bkpt[len(fn_bkpt)-1]):
        fn_bkpt.append(1)
        fn_values.append(0)
    return piecewise_function_from_breakpoints_and_values(fn_bkpt, fn_values, field)

def merge_bkpt(bkpt1, bkpt2):
    i = 0
    j = 0
    bkpt_new = []
    while i < len(bkpt1) and j < len(bkpt2):
        if bkpt1[i] > bkpt2[j]:
            bkpt_new.append(bkpt2[j])
            j = j + 1
        elif bkpt1[i] < bkpt2[j]:
            bkpt_new.append(bkpt1[i])
            i = i + 1
        else:
            bkpt_new.append(bkpt1[i])
            i = i + 1
            j = j + 1
    if i == len(bkpt1) and j != len(bkpt2):
        bkpt_new = bkpt_new + bkpt2[j:len(bkpt2)]
    elif i != len(bkpt1) and j == len(bkpt2):
        bkpt_new = bkpt_new + bkpt1[i:len(bkpt1)]
    return bkpt_new

@cached_function
def find_epsilon_interval(fn, perturb):
    if fn.is_continuous() or fn.is_discrete():
        return find_epsilon_interval_continuous(fn, perturb)
    else:
        return find_epsilon_interval_general(fn, perturb)

def find_largest_epsilon(fn, perturb):
    """
    Compute the proper rescaling of a given perturbation function.
    If the largest epsilon is zero, we should try a different perturbation instead.
    """
    minus_epsilon, plus_epsilon = find_epsilon_interval(fn, perturb)
    return min(abs(minus_epsilon), plus_epsilon)

###
### Moves
###

class FunctionalDirectedMove (FastPiecewise):
    # FIXME: At the moment, does not reduce modulo 1, in contrast to old code!

    def __init__(self, domain_intervals, directed_move):
        function = fast_linear_function(directed_move[0], directed_move[1])
        pieces = [ (interval, function) for interval in domain_intervals ]
        FastPiecewise.__init__(self, pieces)
        self.directed_move = directed_move       # needed?

    def __repr__(self):
        return "<FunctionalDirectedMove %s with domain %s, range %s>" % (self.directed_move, self.intervals(), self.range_intervals())

    def sign(self):
        return self.directed_move[0]

    def is_functional(self):
        return True

    def __getitem__(self, item):
        return self.directed_move[item]

    def can_apply(self, x):
        try:
            self(x)
            return True
        except ValueError:
            return False

    def apply_ignoring_domain(self, x):
        move_sign = self.sign()
        if move_sign == 1:
            next_x = fractional(x + self.directed_move[1])
        elif move_sign == -1:
            next_x = fractional(self.directed_move[1]-x)
        return next_x

    def apply_to_coho_interval(self, interval, inverse=False):
        # This does not do error checking.  Some code depends on this fact!
        # FIXME: This should be made clear in the name of this function.
        if len(interval) <= 2:
            interval = coho_interval_from_interval(interval) # FIXME: Can be removed if FastPiecewise exclusively uses coho intervals.
        directed_move = self.directed_move
        move_sign = directed_move[0]
        if move_sign == 1:
            if inverse:
                result = closed_or_open_or_halfopen_interval(interval[0] - directed_move[1], interval[1] - directed_move[1], \
                                                             interval.left_closed, interval.right_closed)
            else:
                result = closed_or_open_or_halfopen_interval(interval[0] + directed_move[1], interval[1] + directed_move[1], \
                                                             interval.left_closed, interval.right_closed)
        elif move_sign == -1:
            result = closed_or_open_or_halfopen_interval(directed_move[1] - interval[1], directed_move[1] - interval[0], \
                                                         interval.right_closed, interval.left_closed)
        else:
            raise ValueError, "Move not valid: %s" % list(move)
        return result

    def range_intervals(self):
        return [ self.apply_to_coho_interval(interval) for interval in self.intervals() ] 

    def is_identity(self):
        return self.directed_move[0] == 1 and self.directed_move[1] == 0

    def minimal_triples(self): # unused
        """
        Does not output symmetric pairs!  Rather, maps positive translations to horizontal faces
        and negative translations to vertical faces.
        """
        if self.directed_move[0] == 1:                      # translation
            t = self.directed_move[1]
            if t >= 0:
                return [ (interval, [t], (interval[0] + t, interval[1] + t)) for interval in self.intervals() ]
            else:
                return [ ([-t], (interval[0] + t, interval[1] + t), interval) for interval in self.intervals() ]
        elif self.directed_move[0] == -1: 
            r = self.directed_move[1]
            return [ (interval, (r - interval[0], r - interval[1]), r) for interval in self.intervals() ]
        else:
            raise ValueError, "Move not valid: %s" % list(move)

    def restricted(self, intervals):
        """ 
        Return a new move that is the restriction of domain and codomain of `self` to `intervals`.
        (The result may have the empty set as its domain.)
        """
        domain = self.intervals()                        # sorted.
        preimages = [ self.apply_to_coho_interval(interval, inverse=True) for interval in intervals ]
        preimages.sort(key=coho_interval_left_endpoint_with_epsilon)
        new_domain = list(intersection_of_coho_intervals([domain, intervals, preimages]))
        return FunctionalDirectedMove(new_domain, self.directed_move)

@cached_function
def generate_functional_directed_moves(fn, restrict=False):
    """
    Compute the moves (translations and reflections) relevant for the uncovered interval
    (if restrict is True) or for all intervals (if restrict is False).
    """
    ### FIXME: Do we also have to take care of edges of some
    ### full-dimensional additive faces sometimes?
    if restrict:
        # Default is to generate moves for ALL uncovered intervals
        intervals = generate_uncovered_intervals(fn)
    else:
        intervals = None
    moves = dict()
    for face in generate_maximal_additive_faces(fn):
        if face.is_directed_move():
            fdm = face.functional_directed_move(intervals)
            if fdm.intervals():
                if fdm.directed_move in moves:
                    moves[fdm.directed_move] = merge_functional_directed_moves(moves[fdm.directed_move], fdm)
                else:
                    moves[fdm.directed_move] = fdm
    return list(moves.values())

def is_directed_move_possible(x, move):
    return move.can_apply(x)

def plot_moves(seed, moves, colors=None, ymin=0, ymax=1):
    if colors is None:
        colors = rainbow(len(moves))
    g = Graphics()
    g += line([(seed,ymin), (seed,ymax)], color="mediumspringgreen", legend_label="seed value")
    y = 0
    covered_interval = [0,1]
    ## If I pass legend_label to arrow, it needs a legend_color key as well on Sage 6.x;
    ## but in Sage 5.11 that key is unknown, causing repeated warnings. So don't put a legend_label for now. 
    keys = { 'zorder': 7 #, 'legend_label': "moves" 
         }
    for move, color in itertools.izip(moves, colors):
        if move[0] == 1 and move[1] == 0:
            continue                                        # don't plot the identity
        next_x = move.apply_ignoring_domain(seed)
        arrow_interval = [min(seed, next_x), max(seed, next_x)]
        if (len(interval_intersection(covered_interval, arrow_interval)) == 2):
            y += 0.04
            covered_interval = arrow_interval
        else:
            y += 0.002
            covered_interval[0] = min(covered_interval[0], arrow_interval[0])
            covered_interval[1] = max(covered_interval[1], arrow_interval[1])
        midpoint_x = (seed + next_x) / 2
        if move[0] == -1:
            # Reflection
            bezier_y = y + min(0.03, 0.3 * float(abs(move[1]/2 - seed)))
            g += arrow(path = [[(seed, y), (midpoint_x, bezier_y),
                                (next_x, y)]],
                       head = 2, color = color, **keys)
            ## Plot the invariant point somehow?
            #g += point((move[1]/2, y + 0.03), color=color)
        elif move[0] == 1:
            # Translation
            g += arrow((seed, y), (next_x, y), color=color, **keys)
        else:
            raise ValueError, "Bad move: %s" % list(move)
        delete_one_time_plot_kwds(keys)
        g += text("%s" % list(move), (midpoint_x, y), \
                  vertical_alignment="bottom", \
                  horizontal_alignment="center", \
                  color=color, zorder = 7)
    return g

def plot_possible_directed_moves(seed, directed_moves, fn):
    possible_moves = [ directed_move for directed_move in directed_moves 
                       if is_directed_move_possible(seed, directed_move) ]
    colors = [ "blue" for move in possible_moves ]
    return plot_moves(seed, possible_moves, colors)

def plot_possible_and_impossible_directed_moves(seed, directed_moves, fn):
    colors = [ "blue" if is_directed_move_possible(seed, directed_move) \
               else "red" for directed_move in directed_moves ]
    return plot_moves(seed, directed_moves, colors)


def plot_walk(walk_dict, color="black", ymin=0, ymax=1, **kwds):
    #return point([ (x,0) for x in walk_dict.keys()])
    g = Graphics()
    kwds['legend_label'] = "reachable orbit"
    for x in walk_dict.keys():
        g += line([(x,ymin), (x,ymax)], color=color, zorder=-4, **kwds)
        delete_one_time_plot_kwds(kwds)
    return g

def plot_intervals(intervals, ymin=0, ymax=1, legend_label='not covered'):
    g = Graphics()
    kwds = { 'legend_label': legend_label }
    for interval in intervals:
        g += polygon([(interval[0], ymin), (interval[1], ymin),
                      (interval[1], ymax), (interval[0], ymax)],
                     color="yellow", zorder = -8, **kwds)
        delete_one_time_plot_kwds(kwds)
    return g



import collections
_closed_or_open_or_halfopen_interval = collections.namedtuple('Interval', ['a', 'b', 'left_closed', 'right_closed'])

class closed_or_open_or_halfopen_interval (_closed_or_open_or_halfopen_interval):
    def __repr__(self):
        if self.a == self.b and self.left_closed and self.right_closed:
            r = "{" + repr(self.a) + "}"
        else:
            r = ("[" if self.left_closed else "(") \
                + repr(self.a) + ", " + repr(self.b) \
                + ("]" if self.right_closed else ")")
        return "<Int" + r + ">"

    def _sage_input_(self, sib, coerced):
        """
        Produce an expression which will reproduce this value when evaluated.
        """
        if self.a == self.b and self.left_closed and self.right_closed:
            return sib.name('singleton_interval')(sib(self.a))
        else:
            if self.left_closed and self.right_closed:
                name = 'closed_interval'
            elif self.left_closed and not self.right_closed:
                name = 'right_open_interval'
            elif not self.left_closed and self.right_closed:
                name = 'left_open_interval'
            else:
                name = 'open_interval'
            return sib.name(name)(sib(self.a), sib(self.b))

def closed_interval(a, b):
    return closed_or_open_or_halfopen_interval(a, b, True, True)

def open_interval(a, b):
    return closed_or_open_or_halfopen_interval(a, b, False, False)

def singleton_interval(a):
    return closed_or_open_or_halfopen_interval(a, a, True, True)

def left_open_interval(a, b):
    return closed_or_open_or_halfopen_interval(a, b, False, True)

def right_open_interval(a, b):
    return closed_or_open_or_halfopen_interval(a, b, True, False)

def coho_interval_from_interval(int):
    if len(int) == 0:
        raise ValueError, "An empty interval does not have a coho_interval representation"
    elif len(int) == 1:
        return singleton_interval(int[0])
    elif len(int) == 2:
        return closed_interval(int[0], int[1])
    else:
        raise ValueError, "Not an interval: %s" % (int,)

def interval_length(interval):
    """
    Determine the length of the given `interval`.

    `interval` can be old-fashioned or coho.
    """
    if len(interval) <= 1:
        return 0
    elif interval[1] >= interval[0]:
        return interval[1] - interval[0]
    else:
        return 0

def coho_interval_left_endpoint_with_epsilon(i):
    """Return (x, epsilon)
    where x is the left endpoint
    and epsilon is 0 if the interval is left closed and 1 otherwise.
    """
    if len(i) == 0:
        raise ValueError, "An empty interval does not have a left endpoint."
    elif len(i) <= 2:
        # old-fashioned closed interval or singleton
        return i[0], 0 # Scanning from the left, turn on at left endpoint.
    else:
        # coho interval
        return i.a, 0 if i.left_closed else 1

def coho_interval_right_endpoint_with_epsilon(i):
    """Return (x, epsilon)
    where x is the right endpoint
    and epsilon is 1 if the interval is right closed and 0 otherwise.
    """
    if len(i) == 0:
        raise ValueError, "An empty interval does not have a right endpoint."
    elif len(i) == 1:
        # old-fashioned singleton
        return i[0], 1 # Scanning from the left, turn off at that point plus epsilon
    elif len(i) == 2:
        # old-fashioned proper closed interval
        return i[1], 1 # Scanning from the left, turn off at right endpoint plus epsilon
    else:
        # coho interval
        return i.b, 1 if i.right_closed else 0

def scan_coho_interval_left_endpoints(interval_list, tag=None, delta=-1):
    """Generate events of the form `(x, epsilon), delta, tag.`

    This assumes that `interval_list` is sorted from left to right,
    and that the intervals are pairwise disjoint.
    """
    for i in interval_list:
        yield coho_interval_left_endpoint_with_epsilon(i), delta, tag

def scan_coho_interval_right_endpoints(interval_list, tag=None, delta=+1):
    """Generate events of the form `(x, epsilon), delta, tag.`

    This assumes that `interval_list` is sorted from left to right,
    and that the intervals are pairwise disjoint.
    """
    for i in interval_list:
        yield coho_interval_right_endpoint_with_epsilon(i), delta, tag

def scan_coho_interval_list(interval_list, tag=None, on_delta=-1, off_delta=+1):
    """Generate events of the form `(x, epsilon), delta, tag.`

    This assumes that `interval_list` is sorted, and 
    that the intervals are pairwise disjoint.

    delta is -1 for the beginning of an interval ('on').
    delta is +1 for the end of an interval ('off'). 

    This is so that the events sort lexicographically in a way that if
    we have intervals whose closures intersect in one point, such as
    [a, b) and [b, c], we see first the 'on' event and then the 'off'
    event.  In this way consumers of the scan can easily implement merging 
    of such intervals. 

    If merging is not desired, set on_delta=+1, off_delta=-1. 

    EXAMPLES::

        sage: list(scan_coho_interval_list([closed_or_open_or_halfopen_interval(1, 2, True, False), closed_or_open_or_halfopen_interval(2, 3, True, True)]))
        [((1, 0), -1, None), ((2, 0), -1, None), ((2, 0), 1, None), ((3, 1), 1, None)]
    """
    return merge(scan_coho_interval_left_endpoints(interval_list, tag, on_delta), 
                 scan_coho_interval_right_endpoints(interval_list, tag, off_delta))

## def scan_set_difference(a, b):
##     """`a` and `b` should be event generators."""

from heapq import *

def scan_union_of_coho_intervals_minus_union_of_coho_intervals(interval_lists, remove_lists):
    # Following uses the lexicographic comparison of the tuples.
    scan = merge(merge(*[scan_coho_interval_list(interval_list, True) for interval_list in interval_lists]),
                 merge(*[scan_coho_interval_list(remove_list, False) for remove_list in remove_lists]))
    interval_indicator = 0
    remove_indicator = 0
    on = False
    for ((x, epsilon), delta, tag) in scan:
        was_on = on
        if tag:                                       # interval event
            interval_indicator -= delta
            assert(interval_indicator) >= 0
        else:                                           # remove event
            remove_indicator -= delta
            assert(remove_indicator) >= 0
        now_on = interval_indicator > 0 and remove_indicator == 0
        if not was_on and now_on: # switched on
            yield (x, epsilon), -1, None
        elif was_on and not now_on: # switched off
            yield (x, epsilon), +1, None
        on = now_on
    # No unbounded intervals:
    assert interval_indicator == 0
    assert remove_indicator == 0

def intersection_of_coho_intervals(interval_lists):
    """Compute the intersection of the union of intervals. 
    
    Each interval_list must be sorted, but intervals may overlap.  In
    this case, the output is broken into non-overlapping intervals at
    the points where the overlap multiplicity changes.
    
    EXAMPLES::

        sage: list(intersection_of_coho_intervals([[[1,2]], [[2,3]]]))
        [<Int{2}>]
        sage: list(intersection_of_coho_intervals([[[1,2], [2,3]], [[0,4]]]))
        [<Int[1, 2)>, <Int{2}>, <Int(2, 3]>]
        sage: list(intersection_of_coho_intervals([[[1,3], [2,4]], [[0,5]]]))
        [<Int[1, 2)>, <Int[2, 3]>, <Int(3, 4]>]
        sage: list(intersection_of_coho_intervals([[[1,2], left_open_interval(2,3)], [[0,4]]]))
        [<Int[1, 2]>, <Int(2, 3]>]
        sage: list(intersection_of_coho_intervals([[[1,3]], [[2,4]]]))
        [<Int[2, 3]>]
    """
    scan = merge(*[scan_coho_interval_list(interval_list, tag=index) for index, interval_list in enumerate(interval_lists)])
    interval_indicators = [ 0 for interval_list in interval_lists ]
    (on_x, on_epsilon) = (None, None)
    for ((x, epsilon), delta, index) in scan:
        was_on = all(on > 0 for on in interval_indicators)
        interval_indicators[index] -= delta
        assert interval_indicators[index] >= 0
        now_on = all(on > 0 for on in interval_indicators)
        if was_on: 
            assert on_x is not None
            assert on_epsilon >= 0
            assert epsilon >= 0
            if (on_x, on_epsilon) < (x, epsilon):
                yield closed_or_open_or_halfopen_interval(on_x, x,
                                                          on_epsilon == 0, epsilon > 0)
        if now_on:
            (on_x, on_epsilon) = (x, epsilon)
        else:
            (on_x, on_epsilon) = (None, None)
    assert all(on == 0 for on in interval_indicators) # no unbounded intervals

def coho_intervals_intersecting(a, b):
    """
    Determine if the two intervals intersect in at least 1 point.

    EXAMPLES::

        sage: coho_intervals_intersecting(singleton_interval(1), singleton_interval(1))
        True
        sage: coho_intervals_intersecting(singleton_interval(1), singleton_interval(2))
        False
        sage: coho_intervals_intersecting(singleton_interval(1), open_interval(1,2))
        False
        sage: coho_intervals_intersecting(singleton_interval(1), right_open_interval(1,2))
        True
    """
    intervals = list(intersection_of_coho_intervals([[a], [b]]))
    assert len(intervals) <= 1
    return len(intervals) == 1

def coho_intervals_intersecting_full_dimensionally(a, b):
    """
    Determine if the two intervals intersect in a proper interval.

    EXAMPLES::

        sage: coho_intervals_intersecting_full_dimensionally(singleton_interval(1), singleton_interval(1))
        False
        sage: coho_intervals_intersecting_full_dimensionally(singleton_interval(1), singleton_interval(2))
        False
        sage: coho_intervals_intersecting_full_dimensionally(singleton_interval(1), open_interval(1,2))
        False
        sage: coho_intervals_intersecting_full_dimensionally(singleton_interval(1), right_open_interval(1,2))
        False
        sage: coho_intervals_intersecting_full_dimensionally(open_interval(0,2), right_open_interval(1,3))
        True
    """
    intervals = list(intersection_of_coho_intervals([[a], [b]]))
    assert len(intervals) <= 1
    return len(intervals) == 1 and interval_length(intervals[0]) > 0

def coho_interval_list_from_scan(scan, old_fashioned_closed_intervals=False):
    """Actually returns a generator."""
    indicator = 0
    (on_x, on_epsilon) = (None, None)
    for ((x, epsilon), delta, tag) in scan:
        was_on = indicator > 0
        indicator -= delta
        assert indicator >= 0
        now_on = indicator > 0
        if not was_on and now_on:                        # switched on
            (on_x, on_epsilon) = (x, epsilon)
        elif was_on and not now_on:                     # switched off
            assert on_x is not None
            assert on_epsilon >= 0
            assert epsilon >= 0
            if (on_x, on_epsilon) < (x, epsilon):
                left_closed = on_epsilon == 0
                right_closed = epsilon > 0
                if old_fashioned_closed_intervals and left_closed and right_closed and on_x < x:
                    yield (on_x, x)
                else:
                    yield closed_or_open_or_halfopen_interval(on_x, x, left_closed, right_closed)
            (on_x, on_epsilon) = (None, None)
    assert indicator == 0

def union_of_coho_intervals_minus_union_of_coho_intervals(interval_lists, remove_lists, old_fashioned_closed_intervals=False):
    """Compute a list of closed/open/half-open intervals that represent
    the set difference of `interval` and the union of the intervals in
    `remove_list`.

    Assume each of the lists in `interval_lists' and `remove_lists` are sorted (and
    each pairwise disjoint).  Returns a sorted list.

    EXAMPLES::

        sage: union_of_coho_intervals_minus_union_of_coho_intervals([[[0,10]]], [[[2,2], [3,4]]])
        [<Int[0, 2)>, <Int(2, 3)>, <Int(4, 10]>]
        sage: union_of_coho_intervals_minus_union_of_coho_intervals([[[0, 10]]], [[[1, 7]], [[2, 5]]])
        [<Int[0, 1)>, <Int(7, 10]>]
        sage: union_of_coho_intervals_minus_union_of_coho_intervals([[[0,10], closed_or_open_or_halfopen_interval(10, 20, False, True)]], [])
        [<Int[0, 20]>]
        sage: union_of_coho_intervals_minus_union_of_coho_intervals([[[0,10], closed_or_open_or_halfopen_interval(10, 20, False, True)]], [], old_fashioned_closed_intervals=True)
        [(0, 20)]
    """
    gen = coho_interval_list_from_scan(scan_union_of_coho_intervals_minus_union_of_coho_intervals(interval_lists, remove_lists), old_fashioned_closed_intervals)
    return list(gen)

def proper_interval_list_from_scan(scan):
    """Return a generator of the proper intervals [a, b], a<b, in the `scan`.

    This ignores whether intervals are open/closed/half-open.
    """
    indicator = 0
    (on_x, on_epsilon) = (None, None)
    for ((x, epsilon), delta, tag) in scan:
        was_on = indicator > 0
        indicator -= delta
        assert indicator >= 0
        now_on = indicator > 0
        if not was_on and now_on:                        # switched on
            (on_x, on_epsilon) = (x, epsilon)
        elif was_on and not now_on:                     # switched off
            assert on_x is not None
            assert on_epsilon >= 0
            assert epsilon >= 0
            if on_x < x:
                yield [on_x, x]
            (on_x, on_epsilon) = (None, None)
    assert indicator == 0


# size has to be a positive integer
def lattice_plot(A, A0, t1, t2, size):
    size = size + 1
    x0 = A + (A0-A)/2
    p1 = points((x,y) for x in range(size) for y in range(size)) + points((-x,y) for x in range(size) for y in range(size))
    p2 = points((-x,-y) for x in range(size) for y in range(size)) + points((x,-y) for x in range(size) for y in range(size))
    p3 = plot((A-x0-x*t1)/t2, (x,-size + 1, size - 1), color = "red")
    p4 = plot((A0-x0-x*t1)/t2, (x,-size + 1,size - 1), color = "red")
    return p1+p2+p3+p4

# 

class UnimplementedError (Exception):
    pass

def generate_symbolic(fn, components, field=None):
    if fn.is_continuous() or fn.is_discrete():
        return generate_symbolic_continuous(fn, components, field=field)
    else:
        return generate_symbolic_general(fn, components, field=field)

def generate_additivity_equations(fn, symbolic, field, f=None):
    if fn.is_continuous() or fn.is_discrete():
        return generate_additivity_equations_continuous(fn, symbolic, field, f=f)
    else:
        return generate_additivity_equations_general(fn, symbolic, field, f=f)

def rescale_to_amplitude(perturb, amplitude):
    """For plotting purposes, rescale the function `perturb` so that its
    maximum (supremum) absolute function value is `amplitude`.
    """
    current_amplitude = max([ abs(x) for limits in perturb.limits_at_end_points() for x in limits if x is not None])
    if current_amplitude != 0:
        return perturb * (amplitude/current_amplitude)
    else:
        return perturb

# Global figsize for all plots made by show_plots.
show_plots_figsize = 10

def show_plot(graphics, show_plots, tag, object=None, **show_kwds):
    """
    Display or save `graphics`.

    `show_plots` can be one of: `False` (do nothing), 
    `True` (use `show` to display on screen),
    a string (file name format such as "FILENAME-%s.pdf", 
    where %s is replaced by `tag`.
    """
    plot_kwds_hook(show_kwds)
    if isinstance(show_plots, str):
        graphics.save(show_plots % tag, figsize=show_plots_figsize, **show_kwds)
    elif show_plots:
        graphics.show(figsize=show_plots_figsize, **show_kwds)

def plot_rescaled_perturbation(perturb, xmin=0, xmax=1, **kwds):
    return plot(rescale_to_amplitude(perturb, 1/10), xmin=xmin,
                xmax=xmax, color='magenta', legend_label="perturbation (rescaled)", **kwds)

check_perturbation_plot_three_perturbations = True

def basic_perturbation(fn, index):
    """
    Get a basic perturbation of `fn`.  `index` counts from 1 (to match the labels in the diagrams). 
    """
    if not hasattr(fn, '_perturbations'):
        extremality_test(fn, show_plots=False)
    if hasattr(fn, '_perturbations'):
        try: 
            return fn._perturbations[index-1]
        except IndexError:
            raise IndexError, "Bad perturbation index"
    raise ValueError, "No perturbations"

def plot_perturbation_diagram(fn, perturbation=None, xmin=0, xmax=1):
    """
    Plot a perturbation of `fn`.
    
    `perturbation` is either a perturbation function, or an integer
    (which designates a basic perturbation of `fn` via
    `basic_perturbation`).  If `perturbation` is not provided, it
    defaults to the perturbation indexed 1.

    To show only a part of the diagram, use::

        sage: show(plot_perturbation_diagram(h, 1), xmin=0.25, xmax=0.35, ymin=0.25, ymax=0.35)  # not tested
    """
    if perturbation is None:
       perturbation = 1
    if isinstance(perturbation, Integer):
        perturbation = basic_perturbation(fn, perturbation)
    epsilon_interval = find_epsilon_interval(fn, perturbation)
    epsilon = min(abs(epsilon_interval[0]), epsilon_interval[1])
    p = plot_rescaled_perturbation(perturbation, xmin=xmin, xmax=xmax)
    if check_perturbation_plot_three_perturbations:
        p += plot(fn + epsilon_interval[0] * perturbation, xmin=xmin, xmax=xmax, color='red', legend_label="-perturbed (min)")
        p += plot(fn + epsilon_interval[1] * perturbation, xmin=xmin, xmax=xmax, color='blue', legend_label="+perturbed (max)")
        if -epsilon != epsilon_interval[0]:
            p += plot(fn + (-epsilon) * perturbation, xmin=xmin, xmax=xmax, color='orange', legend_label="-perturbed (matches max)")
        elif epsilon != epsilon_interval[1]:
            p += plot(fn + epsilon * perturbation, xmin=xmin, xmax=xmax, color='cyan', legend_label="+perturbed (matches min)")
    else:
        label = "-perturbed"
        if -epsilon == epsilon_interval[0]:
            label += " (min)"
        else:
            label += " (matches max)"
        p += plot(fn - epsilon * perturbation, xmin=xmin, xmax=xmax, color='red', legend_label=label)
        label = "+perturbed"
        if epsilon == epsilon_interval[1]:
            label += " (max)"
        else:
            label += " (matches min)"
        p += plot(fn + epsilon * perturbation, xmin=xmin, xmax=xmax, color='blue', legend_label=label)
    p += plot(fn, xmin=xmin, xmax=xmax, color='black', thickness=2,
             legend_label="original function", **ticks_keywords(fn))
    return p

def check_perturbation(fn, perturb, show_plots=False, show_plot_tag='perturbation', xmin=0, xmax=1, **show_kwds):
    epsilon_interval = find_epsilon_interval(fn, perturb)
    epsilon = min(abs(epsilon_interval[0]), epsilon_interval[1])
    #logging.info("Epsilon for constructed perturbation: %s" % epsilon)
    if show_plots:
        logging.info("Plotting perturbation...")
        p = plot_perturbation_diagram(fn, perturb, xmin=xmin, xmax=xmax)
        show_plot(p, show_plots, tag=show_plot_tag, object=fn, **show_kwds)
        logging.info("Plotting perturbation... done")
    assert epsilon > 0, "Epsilon should be positive, something is wrong"
    #logging.info("Thus the function is not extreme.")  ## Now printed by caller.

def generate_perturbations_finite_dimensional(function, show_plots=False, f=None):
    ## FIXME: Perhaps we want an `oversampling` parameter as in generate_perturbations_simple??
    """
    Generate (with "yield") perturbations for `finite_dimensional_extremality_test`.
    """
    covered_intervals = generate_covered_intervals(function)
    uncovered_intervals = generate_uncovered_intervals(function)
    if uncovered_intervals:
        ## Note that in the current implementation, it is not as
        ## efficient as it could be due to too many slope variables,
        ## since the relations between non-covered intervals are not
        ## taken into account.  (No need to warn the user about that,
        ## though.)
        components = copy(covered_intervals)
        components.extend([int] for int in uncovered_intervals)
    else:
        components = covered_intervals
    # FIXME: fraction_field() required because parent could be Integer
    # Ring.  This happens, for example, for three_slope_limit().  
    # We really should have a function to retrieve the field of
    # a FastPiecewise.  But now even .base_ring() fails because
    # FastLinearFunction does not have a .base_ring() method.
    field = function(0).parent().fraction_field()
    symbolic = generate_symbolic(function, components, field=field)
    equation_matrix = generate_additivity_equations(function, symbolic, field, f=f)
    slope_jump_vects = equation_matrix.right_kernel().basis()
    logging.info("Finite dimensional test: Solution space has dimension %s" % len(slope_jump_vects))
    for basis_index in range(len(slope_jump_vects)):
        slope_jump = slope_jump_vects[basis_index]
        perturbation = slope_jump * symbolic
        yield perturbation

def finite_dimensional_extremality_test(function, show_plots=False, f=None, warn_about_uncovered_intervals=True, 
                                        show_all_perturbations=False):
    """
    Solve a homogeneous linear system of additivity equations with one
    slope variable for every component (including every non-covered
    interval) and one jump variable for each (left/right) discontinuity.

    Return a boolean that indicates whether the system has a nontrivial solution.

    EXAMPLES::

        sage: logging.disable(logging.WARN)
        sage: h1 = drlm_not_extreme_2()
        sage: finite_dimensional_extremality_test(h1, show_plots=True)
        False
        sage: h2 = drlm_3_slope_limit()
        sage: finite_dimensional_extremality_test(h2, show_plots=True)
        True
    """
    if show_all_perturbations is None:
        show_all_perturbations = show_plots
    if function.is_discrete():
        return simple_finite_dimensional_extremality_test(function, oversampling=1, show_all_perturbations=show_all_perturbations)
    seen_perturbation = False
    function._perturbations = []
    for index, perturbation in enumerate(generate_perturbations_finite_dimensional(function, show_plots=show_plots, f=f)):
        function._perturbations.append(perturbation)
        check_perturbation(function, perturbation,
                           show_plots=show_plots, show_plot_tag='perturbation-%s' % (index + 1),
                           legend_title="Basic perturbation %s" % (index + 1))
        if not seen_perturbation:
            seen_perturbation = True
            logging.info("Thus the function is NOT extreme.")
            if not show_all_perturbations:
                break
    if not seen_perturbation:
        logging.info("Finite dimensional extremality test did not find a perturbation.")
        uncovered_intervals = generate_uncovered_intervals(function)
        if uncovered_intervals:
            if warn_about_uncovered_intervals:
                logging.warn("There are non-covered intervals, so this does NOT prove extremality.")
        else:
            logging.info("Thus the function is extreme.")
    return not seen_perturbation

def generate_type_1_vertices(fn, comparison, reduced=True):
    if fn.is_continuous() or fn.is_discrete():
        return generate_type_1_vertices_continuous(fn, comparison)
    else:
        return generate_type_1_vertices_general(fn, comparison, reduced=reduced)

def generate_type_2_vertices(fn, comparison, reduced=True):
    if fn.is_continuous() or fn.is_discrete():
        return generate_type_2_vertices_continuous(fn, comparison)
    else:
        return generate_type_2_vertices_general(fn, comparison, reduced=reduced)

@cached_function
def generate_additive_vertices(fn, reduced=True):
    """
    We are returning a set of 6-tuples (x, y, z, xeps, yeps, zeps),
    so that duplicates are removed, and so the result can be cached for later use.

    When reduced=True:
        only outputs fewer triples satisfying `comparison' relation, for the purpose of setting up the system of equations.

    When reduced=False:
        outputs all triples satisfying `comparison' relation, for the purpose of plotting additive_limit_vertices.
    """
    return set(itertools.chain( \
                generate_type_1_vertices(fn, operator.eq, reduced=reduced),\
                generate_type_2_vertices(fn, operator.eq, reduced=reduced)) )

@cached_function
def generate_nonsubadditive_vertices(fn, reduced=True):
    """
    We are returning a set of 6-tuples (x, y, z, xeps, yeps, zeps),
    so that duplicates are removed, and so the result can be cached for later use.

    When reduced=True:
        only outputs fewer triples satisfying `comparison' relation, for the purpose of minimality_test.

    When reduced=False:
        outputs all triples satisfying `comparison' relation, for the purpose of plotting nonsubadditive_limit_vertices.
    """
    return set(itertools.chain( \
                generate_type_1_vertices(fn, operator.lt, reduced=reduced),\
                generate_type_2_vertices(fn, operator.lt, reduced=reduced))  )

def generate_nonsymmetric_vertices(fn, f):
    if fn.is_continuous() or fn.is_discrete():
        return generate_nonsymmetric_vertices_continuous(fn, f)
    else:
        return generate_nonsymmetric_vertices_general(fn, f)

class MaximumNumberOfIterationsReached(Exception):
    pass

def extremality_test(fn, show_plots = False, show_old_moves_diagram=False, f=None, max_num_it = 1000, perturbation_style=default_perturbation_style, phase_1 = False, finite_dimensional_test_first = False, use_new_code=True, show_all_perturbations=False):
    """Check if `fn` is extreme for the group relaxation with the given `f`. 

    If `fn` is discrete, it has to be defined on a cyclic subgroup of
    the reals containing 1, restricted to [0, 1].  The group
    relaxation is the corresponding cyclic group relaxation.

    Otherwise `fn` needs to be defined on the interval [0, 1], and the
    group relaxation is the infinite group relaxation.

    If `f` is not provided, uses the one found by `find_f()`.

    If `show_plots` is True (default: False), show many illustrating diagrams.

    The function first runs `minimality_test`.
    
    In the infinite group case, if `finite_dimensional_test_first` is
    True (default: False), after testing minimality of `fn`, we first
    check if the `finite_dimensional_extremality_test` finds a
    perturbation; otherwise (default) we first check for an
    equivariant perturbation.

    EXAMPLES::

        sage: logging.disable(logging.INFO) # to disable output in automatic tests.
        sage: h = piecewise_function_from_breakpoints_and_values([0, 1/2, 1], [0, 1, 0])
        sage: # This example has a unique candidate for "f", so we don't need to provide one.
        sage: extremality_test(h, False)
        True
        sage: # Same, with plotting:
        sage: extremality_test(h, True) # not tested
        ... lots of plots shown ...
        True
        sage: h = multiplicative_homomorphism(gmic(f=4/5), 3) 
        sage: # This example has several candidates for "f", so provide the one we mean:
        sage: extremality_test(h, True, f=4/15) # not tested
        ... lots of plots shown ...
        True
        sage: g = gj_2_slope()
        sage: gf = restrict_to_finite_group(g)
        sage: # This is now a finite (cyclic) group problem.
        sage: extremality_test(gf, True) # not tested
        ... lots of plots shown ...
        True
    """
    if show_all_perturbations is None:
        show_all_perturbations = show_plots
    do_phase_1_lifting = False
    if f is None:
        f = find_f(fn, no_error_if_not_minimal_anyway=True)
    if f is None or not minimality_test(fn, show_plots=show_plots, f=f):
        logging.info("Not minimal, thus NOT extreme.")
        if not phase_1:
            return False
        else:
            do_phase_1_lifting = True
    if do_phase_1_lifting:
        finite_dimensional_test_first = True
    seen_perturbation = False
    generator = generate_perturbations(fn, show_plots=show_plots, show_old_moves_diagram=show_old_moves_diagram, f=f, max_num_it=max_num_it, finite_dimensional_test_first=finite_dimensional_test_first, perturbation_style=perturbation_style, use_new_code=use_new_code)
    fn._perturbations = []
    for index, perturbation in enumerate(generator):
        fn._perturbations.append(perturbation)
        check_perturbation(fn, perturbation, show_plots=show_plots, 
                           show_plot_tag='perturbation-%s' % (index + 1), 
                           legend_title="Basic perturbation %s" % (index + 1))
        if not seen_perturbation:
            seen_perturbation = True
            logging.info("Thus the function is NOT extreme.")
            if not show_all_perturbations:
                break
    if not seen_perturbation:
        logging.info("Thus the function is extreme.")
    return not seen_perturbation

def generate_perturbations(fn, show_plots=False, show_old_moves_diagram=False, f=None, max_num_it=1000, perturbation_style=default_perturbation_style, finite_dimensional_test_first = False, use_new_code=True):
    """
    Generate (with "yield") perturbations for `extremality_test`.
    """
    if fn.is_discrete():
        all = generate_perturbations_simple(fn, show_plots=show_plots, f=f, oversampling=None)
    else:
        finite = generate_perturbations_finite_dimensional(fn, show_plots=show_plots, f=f)
        covered_intervals = generate_covered_intervals(fn)
        uncovered_intervals = generate_uncovered_intervals(fn)
        if show_plots:
            logging.info("Plotting covered intervals...")
            show_plot(plot_covered_intervals(fn), show_plots, tag='covered_intervals', object=fn)
            logging.info("Plotting covered intervals... done")
        if not uncovered_intervals:
            logging.info("All intervals are covered (or connected-to-covered). %s components." % len(covered_intervals))
            all = finite
        else:
            logging.info("Uncovered intervals: %s", (uncovered_intervals,))
            equi = generate_perturbations_equivariant(fn, show_plots=show_plots, show_old_moves_diagram=show_old_moves_diagram, f=f, max_num_it=max_num_it, perturbation_style=perturbation_style, use_new_code=use_new_code)
            if finite_dimensional_test_first:
                all = itertools.chain(finite, equi)
            else:
                all = itertools.chain(equi, finite)
    for perturbation in all:
        yield perturbation

def generate_perturbations_equivariant(fn, show_plots=False, show_old_moves_diagram=False, f=None, max_num_it=1000, perturbation_style=default_perturbation_style, use_new_code=True):
    if not fn.is_continuous():
        logging.warning("Code for detecting perturbations using moves is EXPERIMENTAL in the discontinuous case.")
    moves = generate_functional_directed_moves(fn)
    logging.debug("Moves relevant for these intervals: %s" % (moves,))
    if use_new_code:
        generator = generate_generic_seeds_with_completion(fn, show_plots=show_plots, max_num_it=max_num_it) # may raise MaximumNumberOfIterationsReached
    else:
        generator = generate_generic_seeds(fn, max_num_it=max_num_it) # may raise MaximumNumberOfIterationsReached
    seen_perturbation = False
    for seed, stab_int, walk_list in generator:
        # for debugging only:
        #global last_seed, last_stab_int, last_walk_list = seed, stab_int, walk_list
        perturb = approx_discts_function(walk_list, stab_int, perturbation_style=perturbation_style, function=fn)
        perturb._seed = seed
        perturb._stab_int = stab_int
        perturb._walk_list = walk_list
        if show_plots and show_old_moves_diagram:
            logging.info("Plotting moves and reachable orbit...")
            g = plot_old_moves_diagram(fn, perturb)
            show_plot(g, show_plots, tag='moves', object=fn)
            logging.info("Plotting moves and reachable orbit... done")
        if show_plots:
            logging.info("Plotting completion diagram with perturbation...")
            g = plot_completion_diagram(fn, perturb)        # at this point, the perturbation has not been stored yet
            show_plot(g, show_plots, tag='completion', object=fn._completion, legend_title="Completion of moves, perturbation", legend_loc="upper left")
            logging.info("Plotting completion diagram with perturbation... done")
        seen_perturbation = True
        yield perturb
    if not seen_perturbation:
        logging.info("Dense orbits in all non-covered intervals.")
        
def plot_old_moves_diagram(fn, perturbation=None, seed=None, stab_int=None, walk_list=None):
    """
    Return a plot of the 'old' moves diagram, superseded by `plot_completion_diagram`.
    """
    if seed is None or stab_int is None or walk_list is None:
        if perturbation is None:
           perturbation = 1
        if isinstance(perturbation, Integer):
            perturbation = basic_perturbation(fn, perturbation)
        if perturbation is not None:
            seed, stab_int, walk_list = perturbation._seed, perturbation._stab_int, perturbation._walk_list
        if seed is None or stab_int is None or walk_list is None:
            raise ValueError, "Need one of `perturbation` or the triple `seed`, `stab_int`, `walk_list`."
    # FIXME: Visualize stability intervals?
    moves = generate_functional_directed_moves(fn)
    uncovered_intervals = generate_uncovered_intervals(fn)
    return (plot_walk(walk_list,thickness=0.7) + 
            plot_possible_directed_moves(seed, moves, fn) + 
            plot_intervals(uncovered_intervals) + plot_covered_intervals(fn))

def plot_completion_diagram(fn, perturbation=None):
    """
    Return a plot of the completion diagram.
    
    To view a part only, use::

        sage: show(plot_completion_diagram(h), xmin=0.3, xmax=0.55, ymin=0.3, ymax=0.55) # not tested
    """
    if not (hasattr(fn, '_completion') and fn._completion.is_complete):
        extremality_test(fn, show_plots=False)
    if fn._completion.plot_background is None:
        fn._completion.plot_background = plot_completion_diagram_background(fn)
    g = fn._completion.plot() 
    if perturbation is None:
        if hasattr(fn, '_perturbations') and fn._perturbations:
            perturbation = fn._perturbations[0]
    elif isinstance(perturbation, Integer):
        perturbation = basic_perturbation(fn, perturbation)
    if perturbation is not None:
        g += plot_function_at_borders(rescale_to_amplitude(perturbation, 1/10), color='magenta', legend_label='perturbation (rescaled)')
    if hasattr(perturbation, '_walk_list'):
        g += plot_walk_in_completion_diagram(perturbation._seed, perturbation._walk_list)
    return g

def lift(fn, show_plots = False, which_perturbation = 1, **kwds):
    # FIXME: Need better interface for perturbation selection.
    if not hasattr(fn, '_perturbations') and extremality_test(fn, show_plots=show_plots, **kwds):
        return fn
    else:
        perturbation = fn._perturbations[0]
        epsilon_interval = find_epsilon_interval(fn, perturbation)
        perturbed = fn._lifted = fn + epsilon_interval[which_perturbation] * perturbation
        ## Following is strictly experimental: It may change what "f" is.
        if 'phase_1' in kwds and kwds['phase_1']:
            perturbed = rescale_to_amplitude(perturbed, 1)
        return perturbed

def lift_until_extreme(fn, show_plots = False, pause = False, **kwds):
    next, fn = fn, None
    while next != fn:
        fn = next
        next = lift(fn, show_plots=show_plots, **kwds)
        if pause and next != fn:
            raw_input("Press enter to continue")
    return next

##############
def lift_new(fn, order, show_plots = False, which_perturbation = 1, **kwds):
    # FIXME: Need better interface for perturbation selection.
    if not hasattr(fn, '_perturbations') and simple_finite_dimensional_extremality_test(fn, show_plots=show_plots, order=order):
        return fn
    else:
        perturbation = fn._perturbations[0]
        epsilon_interval = find_epsilon_interval(fn, perturbation)
        perturbed = fn._lifted = fn + epsilon_interval[which_perturbation] * perturbation
        ## Following is strictly experimental: It may change what "f" is.
        if 'phase_1' in kwds and kwds['phase_1']:
            perturbed = rescale_to_amplitude(perturbed, 1)
        return perturbed

def lift_new_until_extreme(fn, show_plots = False, pause = False, first_oversampling = 4, **kwds):
    order = finite_group_order_from_function_f_oversampling_order(fn, oversampling=first_oversampling)
    next = lift_new(fn, order, show_plots, **kwds)
    while next != fn:
        fn = next
        next = lift_new(fn, order, show_plots=show_plots, **kwds)
        if pause and next != fn:
            raw_input("Press enter to continue")
    return next

##############
def last_lifted(fn):
    while hasattr(fn, '_lifted'):
        fn = fn._lifted
    return fn

def piecewise_function_from_robert_txt_file(filename):
    """The .txt files have 4 rows.  
    1st row = Y values
    2nd row = X values (I don't use these, but I included them in case you want them)
    3rd row = f   (the x coordinate for which I use as f)
    4th row = value at f  (I don't normalize this to 1.  This allows the Y values to range from 0 to this values)

    Also, I don't include the last value (pi(1)) ever because this is
    the same as pi(0) due to periodicity.  So, if you need this last
    value, please attach a 0 to the end of the Y values and an extra x
    value.
    """
    with open(filename) as f:
        yvalues = [QQ(x) for x in f.readline().split()]
        xvalues = [QQ(x) for x in f.readline().split()]
        if xvalues != range(len(yvalues)):
            raise ValueError, "Line 2 (xvalues) need to be consecutive integers"
        xscale = len(xvalues)
        xf = QQ(f.readline())
        yf = QQ(f.readline())
    if yvalues[xf] != yf:
        raise ValueError, "Lines 3/4 on f and value at f are not consistent with line 1."
    return piecewise_function_from_breakpoints_and_values([ x / xscale for x in xvalues ] + [1], [y / yf for y in yvalues] + [0])

def random_piecewise_function(xgrid=10, ygrid=10, continuous_proba=1, symmetry=True):
    """
    Return a random, continuous or discontinuous piecewise linear function defined on [0, 1]
    with breakpoints that are multiples of 1/`xgrid` and values that are multiples of 1/`ygrid`.

    `continuous_proba` (a real number in [0,1]) indicates the probability that the function is (left/right) continuous at a breakpoint. 
    Use continuous_proba = 1 (the default) to get a continuous piecewise linear function.

    Use symmetry=True (the default) to get a symmetric function. 

    EXAMPLES::

        sage: h = random_piecewise_function(10, 10)
        sage: h = random_piecewise_function(10, 10, continuous_proba=4/5, symmetry=True)
        sage: h = random_piecewise_function(10, 10, continuous_proba=4/5, symmetry=False)
    """
    xvalues = [0] + [ x/xgrid for x in range(1, xgrid) ] + [1]
    f = randint(1, xgrid - 1)
    left_midpoint = f / 2
    right_midpoint = (f+xgrid) / 2
    #yvalues = [0] + [ randint(0, ygrid) / ygrid for i in range(1, f) ] + [1] + [ randint(0, ygrid) / ygrid for i in range(f+1, xgrid) ]+ [0]
    yvalues = [0] + [ randint(1, ygrid-1) / ygrid for i in range(1, f) ] + [1] + [ randint(1, ygrid-1) / ygrid for i in range(f+1, xgrid) ]+ [0]
    if symmetry:
        for i in range(1, ceil(left_midpoint)):
            yvalues[f-i] = 1 - yvalues[i]
        if left_midpoint in ZZ:
            yvalues[left_midpoint] = 1/2
        for i in range(f+1, ceil(right_midpoint)):
            yvalues[f + xgrid - i] = 1 - yvalues[i]
        if right_midpoint in ZZ:
            yvalues[right_midpoint] = 1/2
    if continuous_proba == 1:
        return piecewise_function_from_breakpoints_and_values(xvalues, yvalues)
    else:
        piece1 = [ [singleton_interval(xvalues[i]), FastLinearFunction(0, yvalues[i])] for i in range(xgrid+1) ]
        leftlimits = [0]
        rightlimits = []
        for i in range(0, ygrid):
            p = random()
            if p > continuous_proba:
                rightlimits.append(randint(0, ygrid) / ygrid)
            else:
                rightlimits.append(yvalues[i])
            p = random()
            if p > continuous_proba:
                leftlimits.append(randint(0, ygrid) / ygrid)
            else:
                leftlimits.append(yvalues[i+1])
        rightlimits.append(0)
        if symmetry:
            for i in range(1, ceil(left_midpoint)):
                leftlimits[f-i] = 1 - rightlimits[i]
                rightlimits[f-i] = 1 - leftlimits[i]
            if left_midpoint in ZZ:
                rightlimits[left_midpoint] = 1 - leftlimits[left_midpoint]
            leftlimits[f] = 1 - rightlimits[0]
            for i in range(f+1, ceil(right_midpoint)):
                leftlimits[f + xgrid - i] = 1 - rightlimits[i]
                rightlimits[f + xgrid - i] = 1 - leftlimits[i]
            if right_midpoint in ZZ:
                rightlimits[right_midpoint] = 1 - leftlimits[right_midpoint]
            leftlimits[xgrid] = 1 - rightlimits[f]
        slopes = [ (leftlimits[i+1] - rightlimits[i]) * xgrid for i in range(0, xgrid) ]
        intercepts = [ rightlimits[i] - xvalues[i] * slopes[i] for i in range(0, xgrid) ]
        piece2 = [ [open_interval(xvalues[i], xvalues[i+1]), FastLinearFunction(slopes[i], intercepts[i])] for i in range(xgrid) ]
        pieces = [piece1[0]]
        for i in range(xgrid):
            pieces += [piece2[i], piece1[i+1]]
        return FastPiecewise(pieces, merge=True)

def is_QQ_linearly_independent(*numbers):
    """
    Test if `numbers` are linearly independent over `QQ`.

    EXAMPLES::

        sage: logging.disable(logging.INFO)  # Suppress output in automatic tests.
        sage: is_QQ_linearly_independent()
        True
        sage: is_QQ_linearly_independent(1)
        True
        sage: is_QQ_linearly_independent(0)
        False
        sage: is_QQ_linearly_independent(1,2)
        False
        sage: is_QQ_linearly_independent(1,sqrt(2))
        True
        sage: is_QQ_linearly_independent(1+sqrt(2),sqrt(2),1)
        False
    """
    # trivial cases
    if len(numbers) == 0:
        return True
    elif len(numbers) == 1:
        return numbers[0] != 0
    # fast path for rationals
    all_QQ, numbers = is_all_QQ(numbers)
    if all_QQ:
        return False
    # otherwise try to coerce to common number field
    numbers = nice_field_values(numbers, RealNumberField)
    if not is_real_number_field_element(numbers[0]):
        raise ValueError, "Q-linear independence test only implemented for algebraic numbers"
    coordinate_matrix = matrix(QQ, [x.parent().0.coordinates_in_terms_of_powers()(x) for x in numbers])
    return rank(coordinate_matrix) == len(numbers)

def compose_directed_moves(A, B, show_plots=False):
    """
    Compute the directed move that corresponds to the directed move `A` after `B`.
    
    EXAMPLES::

        sage: compose_directed_moves(FunctionalDirectedMove([(5/10,7/10)],(1, 2/10)),FunctionalDirectedMove([(2/10,4/10)],(1,2/10)))
        <FunctionalDirectedMove (1, 2/5) with domain [(3/10, 2/5)], range [<Int[7/10, 4/5]>]>
    """
    #print result_domain_intervals
    if A.is_functional() and B.is_functional():
        A_domain_preimages = [ B.apply_to_coho_interval(A_domain_interval, inverse=True) \
                               for A_domain_interval in A.intervals() ]
        A_domain_preimages.sort(key=coho_interval_left_endpoint_with_epsilon)
        result_domain_intervals = intersection_of_coho_intervals([A_domain_preimages, B.intervals()])
        if result_domain_intervals:
            result = FunctionalDirectedMove(result_domain_intervals, (A[0] * B[0], A[0] * B[1] + A[1]))
        else:
            result = None
    elif not A.is_functional() and B.is_functional():
        A_domain_preimages = [ B.apply_to_coho_interval(A_domain_interval, inverse=True) \
                               for A_domain_interval in A.intervals() ]
        interval_pairs = []
        for A_domain_preimage, A_range in itertools.izip(A_domain_preimages, A.range_intervals()):
            overlapped_ints = intersection_of_coho_intervals([[A_domain_preimage], B.intervals()])
            interval_pairs += [ (overlapped_int, A_range) for overlapped_int in overlapped_ints ]
        if interval_pairs:
            result = DenseDirectedMove(interval_pairs)
        else:
            result = None
    elif A.is_functional() and not B.is_functional():
        interval_pairs = []
        for B_domain_interval, B_range_interval in B.interval_pairs():
            overlapped_ints = intersection_of_coho_intervals([A.intervals(), [B_range_interval]])
            interval_pairs += [ (B_domain_interval, A.apply_to_coho_interval(overlapped_int)) for overlapped_int in overlapped_ints ]
        if interval_pairs:
            result = DenseDirectedMove(interval_pairs)
        else:
            result = None
    else:
        result = None
    if show_plots:
        p = plot(A, color="green", legend_label="A")
        p += plot(B, color="blue", legend_label="B")
        if result:
            p += plot(result, color="red", legend_label="C = A after B")
        show_plot(p, show_plots, tag='compose_directed_moves')
    return result

def merge_functional_directed_moves(A, B, show_plots=False):
    """
    EXAMPLES::

        sage: merge_functional_directed_moves(FunctionalDirectedMove([(3/10, 7/20), (9/20, 1/2)], (1,0)),FunctionalDirectedMove([(3/10, 13/40)], (1,0)))
        <FunctionalDirectedMove (1, 0) with domain [(3/10, 7/20), (9/20, 1/2)], range [<Int[3/10, 7/20]>, <Int[9/20, 1/2]>]>
    """
    if A.directed_move != B.directed_move:
        raise ValueError, "Cannot merge, moves have different operations"
    #merge_two_comp(A.intervals(), B.intervals(), one_point_overlap_suffices=True), 
    C = FunctionalDirectedMove(\
                               A.intervals() + B.intervals(),  # constructor takes care of merging
                               A.directed_move)
    if show_plots:
        p = plot(C, color="cyan", legend_label="C = A merge B", thickness=10)
        p += plot(A, color="green", legend_label="A = %s" % A )
        p += plot(B, color="blue", legend_label="B = %s" % B)
        show_plot(p, show_plots, tag='merge_functional_directed_moves')
    return C

def plot_directed_moves(dmoves, **kwds):
    g = Graphics()
    for dm in dmoves:
        g += plot(dm, **kwds)
        delete_one_time_plot_kwds(kwds)
    return g

def reduce_with_dense_moves(functional_directed_move, dense_moves, show_plots=False):
    """
    EXAMPLES::

        sage: reduce_with_dense_moves(FunctionalDirectedMove([[3/10,7/10]],(1, 1/10)), [DenseDirectedMove([[[2/10,6/10],[2/10,6/10]]])])
        <FunctionalDirectedMove (1, 1/10) with domain [<Int(1/2, 7/10]>], range [<Int(3/5, 4/5]>]>
        sage: reduce_with_dense_moves(FunctionalDirectedMove([[1/10,7/10]],(1, 1/10)), [DenseDirectedMove([[[7/20,5/10],[3/10,5/10]]]), DenseDirectedMove([[[6/20,6/10],[4/10,6/10]]])])
        <FunctionalDirectedMove (1, 1/10) with domain [<Int[1/10, 3/10)>, <Int(1/2, 7/10]>], range [<Int[1/5, 2/5)>, <Int(3/5, 4/5]>]>
    """
    remove_lists = []
    for domain, codomain in itertools.chain(*[ dense_move.interval_pairs() for dense_move in dense_moves ]):
        remove_list = list(intersection_of_coho_intervals([[functional_directed_move.apply_to_coho_interval(codomain, inverse=True)], [domain]]))
        remove_lists.append(remove_list)  # Each remove_list is sorted because each interval is a subinterval of the domain interval.
    #print remove_lists
    difference = union_of_coho_intervals_minus_union_of_coho_intervals([functional_directed_move.intervals()], remove_lists)
    if difference:
        result = FunctionalDirectedMove(difference, functional_directed_move.directed_move)
    else:
        result = None
    if show_plots:
        p = plot(functional_directed_move, color="yellow", thickness=8)
        p += plot_directed_moves(dense_moves)
        if result:
            p += plot(result)
        show_plot(p, show_plots, tag='reduce_with_dense_moves')
    return result

class DirectedMoveCompositionCompletion:

    def __init__(self, directed_moves, show_plots=False, plot_background=None):
        self.show_plots = show_plots
        self.plot_background = plot_background
        self.move_dict = dict()
        self.dense_moves = set()
        self.any_change = False
        self.num_rounds = 0
        for move in directed_moves:
            self.add_move(move)
        self.is_complete = False

    def reduce_move_dict_with_dense_moves(self, dense_moves):
        new_move_dict = dict()
        for key, move in self.move_dict.items():
            new_move = reduce_with_dense_moves(move, dense_moves)
            if new_move:
                new_move_dict[key] = new_move
        self.move_dict = new_move_dict

    def upgrade_or_reduce_dense_interval_pair(self, a_domain, a_codomain):
        another_pass = True
        while another_pass:
            another_pass = False
            for b in self.dense_moves:
                for (b_domain, b_codomain) in b.interval_pairs():
                    if (b_domain[0] <= a_domain[0] and a_domain[1] <= b_domain[1]
                        and b_codomain[0] <= a_codomain[0] and a_codomain[1] <= b_codomain[1]):
                        # is dominated by existing rectangle, exit.
                        return None, None
                    elif (a_domain[0] <= b_domain[0] and b_domain[1] <= a_domain[1]
                        and a_codomain[0] <= b_codomain[0] and b_codomain[1] <= a_codomain[1]):
                        # dominates existing rectangle, do nothing (we take care of that later).
                        pass
                    elif (a_domain[0] == b_domain[0] and a_domain[1] == b_domain[1]
                          and coho_intervals_intersecting(a_codomain, b_codomain)):
                          # simple vertical merge
                        a_codomain = ((min(a_codomain[0], b_codomain[0]), max(a_codomain[1], b_codomain[1])))
                        another_pass = True
                    elif (a_codomain[0] == b_codomain[0] and a_codomain[1] == b_codomain[1]
                          and coho_intervals_intersecting(a_domain, b_domain)):
                          # simple horizontal merge
                        a_domain = ((min(a_domain[0], b_domain[0]), max(a_domain[1], b_domain[1])))
                        another_pass = True
                    elif (coho_intervals_intersecting_full_dimensionally(a_domain, b_domain)
                          and coho_intervals_intersecting_full_dimensionally(a_codomain, b_codomain)):
                        # full-dimensional intersection, extend to big rectangle.
                        logging.info("Applying rectangle lemma")
                        a_domain = ((min(a_domain[0], b_domain[0]), max(a_domain[1], b_domain[1])))
                        a_codomain = ((min(a_codomain[0], b_codomain[0]), max(a_codomain[1], b_codomain[1])))
                        another_pass = True
        return a_domain, a_codomain

    def add_move(self, c):
        if c.is_functional():
            reduced = reduce_with_dense_moves(c, self.dense_moves)
            if reduced is None:
                return
            cdm = c.directed_move
            if cdm in self.move_dict:
                merged = merge_functional_directed_moves(self.move_dict[cdm], reduced, show_plots=False)

                if merged.intervals() != self.move_dict[cdm].intervals():
                    # Cannot compare the functions themselves because of the "hash" magic of FastPiecewise.
                    #print "merge: changed from %s to %s" % (self.move_dict[cdm], merged)
                    self.move_dict[cdm] = merged
                    self.any_change = True
                else:
                    #print "merge: same"
                    pass
            # elif is_move_dominated_by_dense_moves(c, self.dense_moves):
            #     pass
            else:
                self.move_dict[cdm] = reduced
                self.any_change = True
        else:
            # dense move.
            new_dense_moves = []
            for (c_domain, c_codomain) in c.interval_pairs():
                c_domain, c_codomain = self.upgrade_or_reduce_dense_interval_pair(c_domain, c_codomain)
                if c_domain:
                    new_dense_moves.append(DenseDirectedMove([(c_domain, c_codomain)]))
            if not new_dense_moves:
                return 
            dominated_dense_list = [ move for move in self.dense_moves if is_move_dominated_by_dense_moves(move, new_dense_moves) ]
            for move in dominated_dense_list:
                self.dense_moves.remove(move)
            for m in new_dense_moves:
                self.dense_moves.add(m)
            # dominated_functional_key_list = [ key for key, move in self.move_dict.items() if is_move_dominated_by_dense_moves(move, self.dense_moves) ]
            # for key in dominated_functional_key_list:
            #     self.move_dict.pop(key)
            self.reduce_move_dict_with_dense_moves(new_dense_moves)
            self.any_change = True

    def plot(self, *args, **kwds):
        g = plot_directed_moves(list(self.dense_moves) + list(self.move_dict.values()), **kwds)
        if self.plot_background:
            g += self.plot_background
        return g

    def maybe_show_plot(self):
        if self.show_plots:
            logging.info("Plotting...")
            if self.is_complete:
                tag = 'completion'
                title = "Completion of moves" 
            elif self.num_rounds == 0:
                tag = 'completion'
                title = "Initial moves"
            else:
                tag = 'completion'
                title = "Moves after %s completion round%s" % (self.num_rounds, "s" if self.num_rounds > 1 else "")
            show_plot(self.plot(legend_label='moves'), self.show_plots, tag, legend_title=title, legend_loc="upper left", object=self)
            logging.info("Plotting... done")

    def complete_one_round(self):
        self.maybe_show_plot()
        logging.info("Completing %d functional directed moves and %d dense directed moves..." % (len(self.move_dict), len(self.dense_moves)))
        self.any_change = False
        critical_pairs = ([ (a, b) for a in list(self.dense_moves) for b in list(self.dense_moves) ] 
                          + [ (a, b) for a in self.move_dict.keys() for b in list(self.dense_moves) + self.move_dict.keys() ] 
                          + [ (a, b) for a in list(self.dense_moves) for b in  self.move_dict.keys() ])
        for (a, b) in critical_pairs:
            # Get the most current versions of the directed moves.
            # FIXME: We should rather implement a better completion
            # algorithm.
            if type(a) == tuple or type(a) == list:
                a = self.move_dict.get(a, None)
            if type(b) == tuple or type(b) == list:
                b = self.move_dict.get(b, None)

            if not a or not b: 
                continue                                    # critical pair has been killed

            if not a.is_functional() and not b.is_functional():
                new_pairs = []
                for (a_domain, a_codomain) in a.interval_pairs():
                    for (b_domain, b_codomain) in b.interval_pairs():
                        if (coho_intervals_intersecting_full_dimensionally(a_domain, b_domain)
                            and coho_intervals_intersecting_full_dimensionally(a_codomain, b_codomain)):
                            # full-dimensional intersection, extend to big rectangle;
                            # but this is taken care of in add_move.
                            pass
                        elif coho_intervals_intersecting_full_dimensionally(a_codomain, b_domain):
                            # composition of dense moves
                            new_pairs.append((a_domain, b_codomain))
                if new_pairs:
                    d = DenseDirectedMove(new_pairs)
                    if not is_move_dominated_by_dense_moves(d, self.dense_moves):
                        logging.info("New dense move from dense-dense composition: %s" % d)
                        self.add_move(d)
                        # self.maybe_show_plot()
            else:
                if a.is_functional() and b.is_functional():
                    d = check_for_dense_move(a, b)
                    if d and not is_move_dominated_by_dense_moves(d, self.dense_moves):
                        logging.info("New dense move from strip lemma: %s" % d)
                        self.add_move(d)
                        # self.maybe_show_plot()
                c = compose_directed_moves(a, b)
                if c:
                    self.add_move(c)

    def complete(self, max_num_rounds=8, error_if_max_num_rounds_exceeded=True):
        while self.any_change and (max_num_rounds is not None or self.num_rounds < max_num_rounds):
            self.complete_one_round()
            self.num_rounds += 1
        if max_num_rounds is not None and self.num_rounds == max_num_rounds:
            if error_if_max_num_rounds_exceeded:
                raise MaximumNumberOfIterationsReached, "Reached %d rounds of the completion procedure, found %d directed moves and %d dense directed moves, stopping." % (self.num_rounds, len(self.move_dict), len(self.dense_moves))
            else:
                logging.info("Reached %d rounds of the completion procedure, found %d directed moves and %d dense directed moves, stopping." % (self.num_rounds, len(self.move_dict), len(self.dense_moves)))
        else:
            self.is_complete = True
            #self.maybe_show_plot()
            logging.info("Completion finished.  Found %d directed moves and %d dense directed moves." 
                         % (len(self.move_dict), len(self.dense_moves)))


    def results(self):
        ## FIXME: Should return the dense moves somehow as well.
        # if self.dense_moves:
        #     raise UnimplementedError, "Dense moves found, handling them in the following code is not implemented yet."
        return list(self.move_dict.values())


def directed_move_composition_completion(directed_moves, show_plots=False, plot_background=None, max_num_rounds=8, error_if_max_num_rounds_exceeded=True):
    completion = DirectedMoveCompositionCompletion(directed_moves,
                                                   show_plots=show_plots, plot_background=plot_background)
    completion.complete(max_num_rounds=max_num_rounds, error_if_max_num_rounds_exceeded=error_if_max_num_rounds_exceeded)
    return completion.results()

def plot_completion_diagram_background(fn):
    plot_background = plot_function_at_borders(fn, color='black', **ticks_keywords(fn, y_ticks_for_breakpoints=True))
    plot_background += polygon2d([[0,0], [0,1], [1,1], [1,0]], fill=False, color='grey')
    plot_background += plot_function_at_borders(zero_perturbation_partial_function(fn), color='magenta', legend_label='fixed perturbation (mod interpol)', thickness=3)
    return plot_background

@cached_function
def generate_directed_move_composition_completion(fn, show_plots=False, max_num_rounds=8, error_if_max_num_rounds_exceeded=True):
    completion = getattr(fn, "_completion", None)
    if not completion:
        functional_directed_moves = generate_functional_directed_moves(fn)
        if show_plots:
            plot_background = plot_completion_diagram_background(fn)
        else:
            plot_background = None
        completion = fn._completion = DirectedMoveCompositionCompletion(functional_directed_moves,
                                                                        show_plots=show_plots,
                                                                        plot_background=plot_background)
    completion.complete(max_num_rounds=max_num_rounds, error_if_max_num_rounds_exceeded=error_if_max_num_rounds_exceeded)
    return completion.results()

def plot_walk_in_completion_diagram(seed, walk_dict):
    g = line([(seed,0), (seed,1)], color="limegreen", legend_label="seed value", linestyle=':')
    kwds = { 'legend_label': "reachable orbit" }
    for x in walk_dict.keys():
        g += line([(0, x), (seed, x)], color="limegreen", linestyle=':', **kwds)
        delete_one_time_plot_kwds(kwds)
    return g

def apply_functional_directed_moves(functional_directed_moves, seed):
    """
    Return a dictionary whose keys are the reachable orbit of `seed`.

    If `functional_directed_moves` is complete under compositions,
    then this computes the reachable orbit of `seed`, just like
    `deterministic_walk` would.
    """
    #orbit = set()
    orbit = dict()
    for fdm in functional_directed_moves:
        try:
            #orbit.add(fdm(seed))
            element = fdm(seed)
            if element in orbit:
                orbit[element].append(fdm)
            else:
                orbit[element] = [fdm]
        except ValueError:
            pass
    #return sorted(orbit)
    return orbit

def scan_sign_contradiction_point(fdm):
    if fdm.sign() == -1:
        invariant_point = fdm[1] / 2
        if fdm.can_apply(invariant_point):
            assert fdm(invariant_point) == invariant_point
        yield ((invariant_point, 0), 0, fdm)
        yield ((invariant_point, 1), 0, fdm)

def scan_sign_contradiction_points(functional_directed_moves):
     scans = [ scan_sign_contradiction_point(fdm) for fdm in functional_directed_moves ]
     return merge(*scans)

def scan_domains_of_moves(functional_directed_moves):
     scans = [ scan_coho_interval_list(fdm.intervals(), fdm) for fdm in functional_directed_moves ]
     return merge(*scans)

def find_decomposition_into_intervals_with_same_moves(functional_directed_moves, separate_by_sign_contradiction=True):
    scan = scan_domains_of_moves(functional_directed_moves)
    if separate_by_sign_contradiction:
        scan = merge(scan, \
                     scan_sign_contradiction_points(functional_directed_moves))
    moves = set()
    (on_x, on_epsilon) = (None, None)
    for ((x, epsilon), delta, move) in scan:
        if on_x and (on_x, on_epsilon) < (x, epsilon):
            if moves:
                int = closed_or_open_or_halfopen_interval(on_x, x,
                                                          on_epsilon == 0, epsilon > 0)
                yield (int, list(moves))
        (on_x, on_epsilon) = (x, epsilon)
        if delta == -1:                         # beginning of interval
            assert move not in moves
            moves.add(move)
        elif delta == +1:                      # end of interval
            moves.remove(move)
        elif delta == 0:                       # an invariant point
            pass
        else:
            raise ValueError, "Bad scan item"

def find_decomposition_into_stability_intervals_with_completion(fn, show_plots=False, max_num_it=None):
    fn._stability_orbits = []
    completion = generate_directed_move_composition_completion(fn, show_plots=show_plots)

    z = zero_perturbation_partial_function(fn)
    zero_intervals = z.intervals()
    not_fixed_to_zero = union_of_coho_intervals_minus_union_of_coho_intervals([[[0,1]]], [zero_intervals])
    restricted_completion = [ fdm.restricted(not_fixed_to_zero) for fdm in completion ]

    decomposition = find_decomposition_into_intervals_with_same_moves(restricted_completion)
    done_intervals = set()

    for (interval, moves) in decomposition:
        if interval not in done_intervals:
            #print interval
            orbit = set()
            walk_dict = dict()
            seed = (interval.a + interval.b) / 2
            sign_contradiction = False
            for move in moves:
                moved_interval = move.apply_to_coho_interval(interval)
                #print "Applying move %s to %s gives %s." % (move, interval, moved_interval)
                moved_seed = move(seed)
                walk_sign = move.sign()
                done_intervals.add(moved_interval)
                orbit.add(moved_interval)
                if moved_seed in walk_dict and walk_dict[moved_seed][0] != walk_sign:
                    sign_contradiction = True
                walk_dict[moved_seed] = [walk_sign, None, None] 
            if sign_contradiction:
                for y in walk_dict.values():
                    y[0] = 0
            stability_orbit = (list(orbit), walk_dict, None)
            fn._stability_orbits.append(stability_orbit)
    logging.info("Total: %s stability orbits, lengths: %s" % (len(fn._stability_orbits), \
                    [ ("%s+" if to_do else "%s") % len(shifted_stability_intervals) \
                      for (shifted_stability_intervals, walk_dict, to_do) in fn._stability_orbits ]))

def stab_int_length(x):
    (orbit, walk_dict, _) = x
    int = orbit[0]
    return interval_length(int)

def generate_generic_seeds_with_completion(fn, show_plots=False, max_num_it=None):
    # Ugly compatibility interface.
    find_decomposition_into_stability_intervals_with_completion(fn, show_plots=show_plots)
    if not fn._stability_orbits:
        return
    for (orbit, walk_dict, _) in sorted(fn._stability_orbits, key=stab_int_length, reverse=True):
        int = orbit[0]
        if interval_length(int) > 0:
            seed = (int.a + int.b) / 2
            stab_int = closed_or_open_or_halfopen_interval(int.a - seed, int.b - seed, int.left_closed, int.right_closed)
            yield (seed, stab_int, walk_dict)

class DenseDirectedMove ():

    def __init__(self, interval_pairs):
        self._interval_pairs = interval_pairs

    def __repr__(self):
        return "<DenseDirectedMove %s>" % self._interval_pairs

    def is_functional(self):
        return False

    def plot(self, *args, **kwds):
        return sum([polygon(((domain[0], codomain[0]), (domain[1], codomain[0]), (domain[1], codomain[1]), (domain[0], codomain[1])), rgbcolor=kwds.get("rgbcolor", "cyan"), alpha=0.5) + polygon(((domain[0], codomain[0]), (domain[1], codomain[0]), (domain[1], codomain[1]), (domain[0], codomain[1])), color="red", fill=False) for (domain, codomain) in self._interval_pairs])

    def intervals(self):
        return [ domain_interval for (domain_interval, range_interval) in self._interval_pairs ]

    def range_intervals(self):
        return [ range_interval for (domain_interval, range_interval) in self._interval_pairs ]

    def interval_pairs(self):
        return self._interval_pairs
    
def check_for_dense_move(m1, m2):
    # the strip lemma.
    if m1.sign() == 1 and m2.sign() == 1: 
        t1 = m1[1]
        t2 = m2[1]
        if is_QQ_linearly_independent(t1, t2) and t1 >= 0 and t2 >= 0:
            dense_intervals = []
            for m1i in m1.intervals():
                for m2i in m2.intervals():
                    l1, u1 = m1i[0], m1i[1]
                    l2, u2 = m2i[0], m2i[1]
                    L = max(l1, l2)
                    U = min(u1 + t1, u2 + t2)
                    if t1 + t2 <= U - L:
                        dense_intervals.append((L, U))
            if dense_intervals:
                return DenseDirectedMove([(I, I) for I in dense_intervals])
    return None

def is_interval_pair_dominated_by_dense_move(domain_interval, range_interval, dense_move):
    for (dense_domain_interval, dense_range_interval) in dense_move.interval_pairs():
        if coho_interval_contained_in_coho_interval(domain_interval, dense_domain_interval) \
           and coho_interval_contained_in_coho_interval(range_interval, dense_range_interval):
            return True
    return False

def is_interval_pair_dominated_by_dense_moves(domain_interval, range_interval, dense_moves):
    for dense_move in dense_moves:
        if is_interval_pair_dominated_by_dense_move(domain_interval, range_interval, dense_move):
            return True
    return False

def is_move_dominated_by_dense_moves(move, dense_moves):
    for (domain_interval, range_interval) in itertools.izip(move.intervals(), move.range_intervals()):
        if is_interval_pair_dominated_by_dense_moves(domain_interval, range_interval, dense_moves):
            pass
        else:
            return False
    #print "Dominated: %s" % move
    return True

def stuff_with_random_irrational_function():
    while True:
        del1 = randint(1, 100) / 1000
        del2 = randint(1, 60) / 1000
        print "del1 = %s, del2 = %s" % (del1, del2)
        try:
            h = the_irrational_function_t1_t2(del1=del1, del2=del2)
            break
        except ValueError:
            print "... parameters do not describe a function, retrying."
    dmoves = generate_functional_directed_moves(h)
    completion = directed_move_composition_completion(dmoves, max_num_rounds=None)
    plot_directed_moves(completion).show(figsize=40)
